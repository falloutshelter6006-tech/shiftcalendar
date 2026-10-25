import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r: Double
        let g: Double
        let b: Double
        let a: Double

        switch cleaned.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        default:
            r = 0.5
            g = 0.5
            b = 0.5
            a = 1
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // Семантические цвета через UIKit — одинаково предсказуемы в светлой и тёмной теме.
    static var appLabel: Color { Color(uiColor: .label) }
    static var appSecondaryLabel: Color { Color(uiColor: .secondaryLabel) }
    static var appCellBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var appGroupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var appFill: Color { Color(uiColor: .tertiarySystemFill) }
    static var appSeparator: Color { Color(uiColor: .separator) }
}

enum Palette {
    static let hexes = [
        "#3B82F6", "#6366F1", "#8B5CF6", "#EC4899",
        "#F97316", "#F59E0B", "#22C55E", "#14B8A6",
        "#0EA5E9", "#64748B", "#EF4444", "#84CC16"
    ]
}
