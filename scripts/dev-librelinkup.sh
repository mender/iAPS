#!/bin/bash
#
# Developer helper for the LibreLinkUp CGM plugin.
#
# Usage: ./scripts/dev-librelinkup.sh <command>
#
#   check-env       macOS, Xcode, iOS SDK, signing config and submodules
#   set-team <ID>   write the Team ID into the gitignored ConfigOverride.xcconfig
#   test            unit tests of the plugin on a simulator
#   build-sim       Debug build of the plugin framework for a simulator
#   build-app       Debug build of the whole app for a simulator
#   build-device    Debug build of the app for the connected iPhone
#   install-device  install the built app on the connected iPhone
#   logs            stream the plugin log from the connected iPhone
#
set -euo pipefail

cd "$(dirname "$0")/.."

WORKSPACE="FreeAPS.xcworkspace"
PLUGIN_SCHEME="LibreLinkUpCGM"
APP_SCHEME="FreeAPSWorkspace"
SIMULATOR="${IAPS_SIMULATOR:-iPhone 17 Pro}"
MINIMUM_SDK_MAJOR=17

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; exit 1; }

team_id() {
    if [ -n "${IAPS_TEAM_ID:-}" ]; then
        echo "$IAPS_TEAM_ID"
    elif [ -f ConfigOverride.xcconfig ]; then
        awk -F'=' '/^[[:space:]]*DEVELOPER_TEAM/ { gsub(/[[:space:]]/, "", $2); print $2 }' ConfigOverride.xcconfig
    fi
}

device_udid() {
    # The "Devices" section also lists this Mac, so only iOS hardware is considered.
    xcrun xctrace list devices 2>/dev/null |
        awk '/^== Devices ==/ { in_devices = 1; next } /^== / { in_devices = 0 } in_devices && /iPhone|iPad/ { print }' |
        grep -oE '\(([0-9A-Fa-f-]{25,})\)$' | head -1 | tr -d '()' || true
}

app_path() {
    local build_dir
    build_dir=$(xcodebuild -workspace "$WORKSPACE" -scheme "$APP_SCHEME" -configuration Debug \
        -destination "$1" -showBuildSettings 2>/dev/null |
        awk -F' = ' '/ BUILT_PRODUCTS_DIR / { print $2; exit }')
    echo "$build_dir/FreeAPS.app"
}

cmd_check_env() {
    info "macOS $(sw_vers -productVersion)"
    info "$(xcodebuild -version | head -1)"

    local sdk
    sdk=$(xcodebuild -showsdks 2>/dev/null | grep -oE 'iphoneos[0-9]+\.[0-9]+' | tail -1 | sed 's/iphoneos//')
    [ -n "$sdk" ] || fail "No iOS SDK found. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    if [ "${sdk%%.*}" -lt "$MINIMUM_SDK_MAJOR" ]; then
        fail "iOS SDK $sdk is too old; the project needs $MINIMUM_SDK_MAJOR.0 or newer."
    fi
    info "iOS SDK $sdk"

    local team
    team=$(team_id)
    if [ -n "$team" ]; then
        info "Team ID $team (bundle id ru.artpancreas.$team.FreeAPS)"
    else
        warn "No DEVELOPER_TEAM. Simulator builds work; for a device create ConfigOverride.xcconfig with DEVELOPER_TEAM = <TEAM_ID>."
    fi

    if [ -d LoopKit/LoopKit ]; then
        info "Submodules checked out"
    else
        fail "Submodules are missing. Run: git submodule update --init --recursive"
    fi

    local udid
    udid=$(device_udid)
    if [ -n "$udid" ]; then
        info "Connected device $udid"
    else
        warn "No device connected. Device QA needs USB, Trust and Developer Mode enabled."
    fi

    # HealthKit is not available to free personal teams, which is where device builds usually fail.
    warn "For device builds the Apple Developer Program is required: HealthKit and App Groups are not available on a free team."
}

cmd_set_team() {
    local team="${1:-}"
    [ -n "$team" ] || fail "Usage: $0 set-team <TEAM_ID>"
    [[ "$team" =~ ^[A-Z0-9]{10}$ ]] || fail "'$team' does not look like a Team ID (10 characters, A-Z and 0-9)."

    printf 'DEVELOPER_TEAM = %s\n' "$team" > ConfigOverride.xcconfig

    info "Wrote ConfigOverride.xcconfig (gitignored)"
    info "Bundle id: ru.artpancreas.$team.FreeAPS"
    info "App Group: group.com.$team.loopkit.LoopGroup"
    warn "The App Group must exist in the developer portal and be assigned to the FreeAPS, watchkitapp and watchkitextension identifiers."
}

cmd_test() {
    info "Running plugin unit tests on $SIMULATOR"
    xcodebuild test -workspace "$WORKSPACE" -scheme "$PLUGIN_SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -configuration Debug CODE_SIGNING_ALLOWED=NO
}

cmd_build_sim() {
    info "Building $PLUGIN_SCHEME for the simulator"
    xcodebuild build -workspace "$WORKSPACE" -scheme "$PLUGIN_SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -configuration Debug CODE_SIGNING_ALLOWED=NO
}

cmd_build_app() {
    info "Building the app for the simulator"
    xcodebuild build -workspace "$WORKSPACE" -scheme "$APP_SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -configuration Debug CODE_SIGNING_ALLOWED=NO
}

cmd_build_device() {
    local udid team
    udid=$(device_udid)
    [ -n "$udid" ] || fail "No connected iPhone found."
    team=$(team_id)
    [ -n "$team" ] || fail "Set DEVELOPER_TEAM in ConfigOverride.xcconfig or IAPS_TEAM_ID first."

    info "Building the app for device $udid"
    xcodebuild build -workspace "$WORKSPACE" -scheme "$APP_SCHEME" \
        -destination "platform=iOS,id=$udid" \
        -configuration Debug -allowProvisioningUpdates
}

cmd_install_device() {
    local udid app
    udid=$(device_udid)
    [ -n "$udid" ] || fail "No connected iPhone found."

    app=$(app_path "platform=iOS,id=$udid")
    [ -d "$app" ] || fail "$app not found. Run build-device first."

    info "Installing $app on $udid"
    xcrun devicectl device install app --device "$udid" "$app"
}

cmd_logs() {
    local udid team bundle
    udid=$(device_udid)
    team=$(team_id)
    bundle="ru.artpancreas.${team}.FreeAPS"

    if [ -n "$udid" ]; then
        info "Restarting $bundle on $udid with the console attached"
        # devicectl only forwards stdout/stderr; os_log output needs Console.app
        # with the device selected and "LibreLinkUp" typed into the search field.
        xcrun devicectl device process launch --device "$udid" --console --terminate-existing "$bundle"
    else
        info "No device connected, streaming from this Mac instead"
        log stream --level debug --predicate 'subsystem CONTAINS "LibreLinkUp" OR eventMessage CONTAINS "LibreLinkUp"'
    fi
}

case "${1:-}" in
    check-env) cmd_check_env ;;
    set-team) cmd_set_team "${2:-}" ;;
    test) cmd_test ;;
    build-sim) cmd_build_sim ;;
    build-app) cmd_build_app ;;
    build-device) cmd_build_device ;;
    install-device) cmd_install_device ;;
    logs) cmd_logs ;;
    *)
        sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
