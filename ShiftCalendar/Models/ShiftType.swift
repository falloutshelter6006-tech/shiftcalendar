import Foundation
import SwiftUI

/// Тип смены: дневная, ночная, выходной, отпуск и т.п.
struct ShiftType: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var short: String
    var colorHex: String
    var isWorking: Bool = true
    /// Начало смены в минутах от полуночи.
    var startMinutes: Int = 8 * 60
    /// Конец смены в минутах от полуночи. Если меньше начала — смена переходит через полночь.
    var endMinutes: Int = 20 * 60

    var color: Color {
        Color(hex: colorHex)
    }

    var durationHours: Double {
        guard isWorking else { return 0 }
        var diff = endMinutes - startMinutes
        if diff <= 0 { diff += 24 * 60 }
        return Double(diff) / 60
    }

    var durationText: String {
        guard isWorking else { return "—" }
        let hours = durationHours
        if abs(hours.rounded() - hours) < 0.01 {
            return "\(Int(hours.rounded())) ч"
        }
        return String(format: "%.1f ч", hours)
    }

    var timeRangeText: String {
        guard isWorking else { return "Без смены" }
        return "\(Cal.timeText(startMinutes))–\(Cal.timeText(endMinutes))"
    }

    var chipText: String {
        let trimmed = short.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(name.prefix(2)) : trimmed
    }
}
