import Foundation

enum WatchStateKey {
    /// Key under which the encoded `WatchState` travels in the application context.
    static let state = "state"
}

/// A single reading for the watch, already converted to the units the user reads.
struct WatchGlucosePoint: Codable, Hashable, Identifiable {
    var id: Date { date }

    let date: Date
    let value: Double
}

struct WatchState: Codable {
    var glucose: String?
    var trend: String?
    var trendRaw: String?
    var delta: String?
    var glucoseDate: Date?
    /// Recent readings, oldest first, for the chart on the watch face.
    var glucoseHistory: [WatchGlucosePoint] = []
    var lowGlucose: Double?
    var highGlucose: Double?
    /// Above this the reading counts as dangerously high and is drawn red, matching the
    /// phone's chart.
    var veryHighGlucose: Double?
    var units: String?
    var glucoseDateInterval: UInt64?
    var lastLoopDate: Date?
    var lastLoopDateInterval: UInt64?
    var bolusIncrement: Decimal?
    var maxCOB: Decimal?
    var maxBolus: Decimal?
    var carbsRequired: Decimal?
    var bolusRecommended: Decimal?
    var iob: Decimal?
    var cob: Decimal?
    var tempTargets: [TempTargetWatchPreset] = []
    var overrides: [OverridePresets_] = []
    var bolusAfterCarbs: Bool?
    var eventualBG: String?
    var eventualBGRaw: String?
    var displayOnWatch: AwConfig?
    var displayFatAndProteinOnWatch: Bool?
    var confirmBolusFaster: Bool?
    var profilesOrTempTargets: Bool?
    var useNewCalc: Bool?
    var isf: Decimal?
    var override: String?
    var target: Decimal?
    var carbRatio: Decimal?
    var eventualGlucose: Decimal?
    var deltaBG: Decimal?
    var minPredBG: Decimal?
}

struct TempTargetWatchPreset: Codable, Identifiable {
    let name: String
    let id: String
    let description: String
    let until: Date?
}

struct OverridePresets_: Codable, Identifiable {
    let name: String
    let id: String
    let until: Date?
    let description: String
}
