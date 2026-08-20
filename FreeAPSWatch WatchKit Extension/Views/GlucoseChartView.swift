import SwiftUI

/// Sparkline of the recent readings over a dashed grid, with every segment coloured by
/// the reading it leads to. Drawn with plain paths rather than a charting framework:
/// complications render in a tightly constrained environment, and this keeps the view
/// cheap and predictable.
struct GlucoseChartView: View {
    let points: [WatchGlucosePoint]
    let lowThreshold: Double?
    let highThreshold: Double?
    let veryHighThreshold: Double?

    /// Horizontal dashed lines drawn between the thresholds, as on the xDrip chart.
    private let gridLineCount = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                grid(in: geometry.size)
                segments(in: geometry.size)
            }
        }
    }

    // MARK: - Layers

    private func grid(in size: CGSize) -> some View {
        Path { path in
            for value in gridValues {
                let y = self.y(for: value, in: size)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
    }

    /// Each segment is stroked separately so that a stretch out of range stands out,
    /// which is impossible with a single path and one colour.
    private func segments(in size: CGSize) -> some View {
        ForEach(Array(points.enumerated().dropFirst()), id: \.offset) { index, point in
            Path { path in
                path.move(to: position(points[index - 1], in: size))
                path.addLine(to: position(point, in: size))
            }
            .stroke(
                color(for: point.value),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - Geometry

    private var gridValues: [Double] {
        guard let low = lowThreshold, let high = highThreshold, high > low else {
            return []
        }

        let step = (high - low) / Double(gridLineCount + 1)
        return (0 ... (gridLineCount + 1)).map { low + step * Double($0) }
    }

    /// Vertical range of the plot, always wide enough to include the thresholds so that
    /// the grid stays visible even when the curve is flat.
    private var range: (min: Double, max: Double) {
        var lowest = points.map(\.value).min() ?? 0
        var highest = points.map(\.value).max() ?? 1

        if let lowThreshold = lowThreshold { lowest = min(lowest, lowThreshold) }
        if let highThreshold = highThreshold { highest = max(highest, highThreshold) }

        let padding = max((highest - lowest) * 0.1, 0.1)
        return (lowest - padding, highest + padding)
    }

    /// Points are placed by their timestamp rather than by index, so gaps in the data
    /// show up as gaps on the chart instead of silently compressing the timeline.
    private func position(_ point: WatchGlucosePoint, in size: CGSize) -> CGPoint {
        let start = points.first?.date ?? point.date
        let end = points.last?.date ?? point.date
        let span = max(end.timeIntervalSince(start), 1)
        let relativeX = point.date.timeIntervalSince(start) / span

        return CGPoint(x: CGFloat(relativeX) * size.width, y: y(for: point.value, in: size))
    }

    private func y(for value: Double, in size: CGSize) -> CGFloat {
        let range = self.range
        let span = max(range.max - range.min, 0.0001)
        return CGFloat(1 - (value - range.min) / span) * size.height
    }

    private func color(for value: Double) -> Color {
        GlucoseRange.color(for: value, low: lowThreshold, high: highThreshold, veryHigh: veryHighThreshold)
    }
}

/// Shared colouring so the chart, the value and the gauge never disagree.
/// Mirrors how the phone paints glucose: red when low or dangerously high, yellow above
/// the high threshold, and the app's dark green in range.
enum GlucoseRange {
    /// The phone reads this colour from its asset catalogue, which the watch target does
    /// not include, so the same components are declared here.
    static let inRange = Color(red: 0.203, green: 0.663, blue: 0.0)

    static func color(for value: Double?, low: Double?, high: Double?, veryHigh: Double? = nil) -> Color {
        guard let value = value else { return inRange }

        if let low = low, value < low { return .red }
        if let veryHigh = veryHigh, value > veryHigh { return .red }
        if let high = high, value > high { return .yellow }

        return inRange
    }
}
