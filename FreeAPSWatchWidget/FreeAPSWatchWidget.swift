import SwiftUI
import WidgetKit

@main struct FreeAPSWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlucoseWidget()
    }
}

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let state: WatchState

    var glucose: String { state.glucose ?? "--" }
    var trend: String { state.trend ?? "" }
    var delta: String { state.delta ?? "--" }

    var glucoseWithTrend: String {
        trend.isEmpty ? glucose : glucose + " " + trend
    }
}

struct GlucoseProvider: TimelineProvider {
    func placeholder(in _: Context) -> GlucoseEntry {
        GlucoseEntry(date: Date(), state: SharedWatchState.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> Void) {
        let state = context.isPreview ? SharedWatchState.sample : (SharedWatchState.load() ?? SharedWatchState.sample)
        completion(GlucoseEntry(date: Date(), state: state))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<GlucoseEntry>) -> Void) {
        let state = SharedWatchState.load() ?? WatchState()
        let entry = GlucoseEntry(date: Date(), state: state)

        // The phone pushes new readings and reloads the timeline itself; this refresh only
        // covers the case where that push never arrives.
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5 * 60))))
    }
}

struct GlucoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FreeAPSWatchWidget.glucose", provider: GlucoseProvider()) { entry in
            GlucoseWidgetView(entry: entry)
        }
        .configurationDisplayName("Glucose")
        .description("Current glucose and the recent trend.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

struct GlucoseWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: GlucoseEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        default:
            inline
        }
    }

    /// The large module: value, delta and the time of the reading above the two-hour curve.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.glucoseWithTrend)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(valueColor)
                Text(entry.delta)
                    .font(.caption2)
                Spacer(minLength: 0)
                if let date = entry.state.glucoseDate {
                    Text(date, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if entry.state.glucoseHistory.count > 1 {
                GlucoseChartView(
                    points: entry.state.glucoseHistory,
                    lowThreshold: entry.state.lowGlucose,
                    highThreshold: entry.state.highGlucose,
                    veryHighThreshold: entry.state.veryHighGlucose
                )
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var valueColor: Color {
        GlucoseRange.color(
            for: entry.state.glucoseHistory.last?.value,
            low: entry.state.lowGlucose,
            high: entry.state.highGlucose,
            veryHigh: entry.state.veryHighGlucose
        )
    }

    /// Ring gauge with the value in the middle and the target range on the sides,
    /// matching how xDrip presents the small complication.
    @ViewBuilder private var circular: some View {
        if let low = entry.state.lowGlucose, let high = entry.state.highGlucose,
           let value = entry.state.glucoseHistory.last?.value, high > low
        {
            Gauge(value: min(max(value, low), high), in: low ... high) {
                Text(entry.trend)
            } currentValueLabel: {
                Text(entry.glucose)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } minimumValueLabel: {
                Text(bound(low))
                    .font(.system(size: 10))
            } maximumValueLabel: {
                Text(bound(high))
                    .font(.system(size: 10))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(valueColor)
            .containerBackground(.clear, for: .widget)
        } else {
            VStack(spacing: 0) {
                Text(entry.glucose)
                    .font(.title3)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(entry.trend.isEmpty ? entry.delta : entry.trend)
                    .font(.caption2)
            }
            .containerBackground(.clear, for: .widget)
        }
    }

    /// Range bounds are shown without decimals, the way the watch face has room for.
    private func bound(_ value: Double) -> String {
        value < 30 ? String(format: "%.1f", value) : String(Int(value.rounded()))
    }

    private var corner: some View {
        Text(entry.glucoseWithTrend)
            .widgetCurvesContent()
            .widgetLabel(entry.delta)
            .containerBackground(.clear, for: .widget)
    }

    private var inline: some View {
        Text(entry.glucoseWithTrend + " " + entry.delta)
            .containerBackground(.clear, for: .widget)
    }
}
