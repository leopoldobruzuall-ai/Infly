import CoreGraphics
import Foundation

/// Widget point sizes iOS uses on each iPhone screen class (portrait), from Apple's HIG.
/// iOS has no API to ask for these, so previews look them up by screen size.
enum WidgetMetrics {
    static let cornerRadius: CGFloat = 22

    static func size(for size: DesignSize, screen: CGSize) -> CGSize {
        let screen = CGSize(width: min(screen.width, screen.height), height: max(screen.width, screen.height))
        let row = rows.first { screen.width >= $0.width && screen.height >= $0.height } ?? rows[rows.count - 1]
        switch size {
        case .small: return CGSize(width: row.small, height: row.small)
        case .medium: return CGSize(width: row.wide, height: row.small)
        case .large: return CGSize(width: row.wide, height: row.tall)
        case .circular: return CGSize(width: row.accessory, height: row.accessory)
        case .rectangular: return CGSize(width: row.rectangular, height: row.accessory)
        case .inline: return CGSize(width: row.inline, height: 26)
        }
    }

    private struct Row {
        let width: CGFloat, height: CGFloat
        let small: CGFloat, wide: CGFloat, tall: CGFloat
        let accessory: CGFloat, rectangular: CGFloat, inline: CGFloat
    }

    private static let rows = [
        Row(width: 428, height: 926, small: 170, wide: 364, tall: 382, accessory: 76, rectangular: 172, inline: 257),
        Row(width: 414, height: 896, small: 169, wide: 360, tall: 379, accessory: 76, rectangular: 160, inline: 248),
        Row(width: 390, height: 844, small: 158, wide: 338, tall: 354, accessory: 72, rectangular: 160, inline: 234),
        Row(width: 375, height: 812, small: 155, wide: 329, tall: 345, accessory: 72, rectangular: 157, inline: 225),
        Row(width: 375, height: 667, small: 148, wide: 321, tall: 324, accessory: 68, rectangular: 153, inline: 225),
        Row(width: 0, height: 0, small: 141, wide: 292, tall: 311, accessory: 68, rectangular: 153, inline: 225),
    ]
}

/// When a widget's content changes. Times redraw on their own; dates and day counts change at midnight.
enum TimelinePlan {
    static func dates(for design: WidgetDesign?, from now: Date, calendar: Calendar = .current) -> [Date] {
        var dates = [now]
        var day = calendar.startOfDay(for: now)
        for _ in 0..<(design?.kind == .countdown ? 7 : 1) {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
            dates.append(day)
        }
        if let design, design.kind == .countdown, design.countdown.date > now, design.countdown.date < day {
            dates.append(design.countdown.date)
        }
        return dates.sorted()
    }
}
