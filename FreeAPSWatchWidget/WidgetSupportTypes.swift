import Foundation

/// `WatchState` carries this setting, so the widget needs the type to decode it. The app
/// and the watch each declare their own copy for the same reason.
enum AwConfig: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }
    case HR
    case BGTarget
    case steps
    case isf
    case override
}
