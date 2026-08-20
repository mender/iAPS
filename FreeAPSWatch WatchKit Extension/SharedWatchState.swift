import Foundation

/// The watch app and the widget extension run in separate processes, so the latest state
/// is kept in the shared App Group container that both of them can reach.
enum SharedWatchState {
    private static let key = "FreeAPSWatch.lastState"

    private static var defaults: UserDefaults {
        guard let suiteName = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String,
              let shared = UserDefaults(suiteName: suiteName)
        else {
            return .standard
        }
        return shared
    }

    static func save(_ state: WatchState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WatchState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchState.self, from: data)
    }

    /// Placeholder shown in the widget gallery, where no real data exists yet.
    static var sample: WatchState {
        var state = WatchState()
        state.glucose = "6,5"
        state.trend = "→"
        state.delta = "+0,2"
        state.glucoseDate = Date()
        state.lowGlucose = 4
        state.highGlucose = 10
        state.veryHighGlucose = 11
        state.veryHighGlucose = 11
        state.units = "mmol/L"
        state.glucoseHistory = (0 ..< 24).map { step in
            WatchGlucosePoint(
                date: Date().addingTimeInterval(TimeInterval(-300 * (24 - step))),
                value: 6.5 + sin(Double(step) / 3) * 1.5
            )
        }
        return state
    }
}
