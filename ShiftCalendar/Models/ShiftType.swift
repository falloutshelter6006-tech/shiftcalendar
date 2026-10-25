import Foundation
import SwiftUI

enum PayMode: String, Codable, Hashable, CaseIterable {
    case hourly
    case perShift

    var title: String {
        switch self {
        case .hourly: return "За час"
        case .perShift: return "За смену"
        }
    }
}

struct PayRule: Codable, Hashable {
    var mode: PayMode = .hourly
    var hourlyRate: Double = 0
    var shiftRate: Double = 0
    /// Надбавка за ночные часы, % к ставке.
    var nightBonusPercent: Double = 0
}

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
    /// Оплата. Необязательное поле — чтобы читались файлы из версии 1.
    var pay: PayRule?

    var payRule: PayRule {
        pay ?? PayRule()
    }

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
        return Fmt.hours(durationHours)
    }

    var timeRangeText: String {
        guard isWorking else { return "Без смены" }
        return "\(Cal.timeText(startMinutes))–\(Cal.timeText(endMinutes))"
    }

    var chipText: String {
        let trimmed = short.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(name.prefix(2)) : trimmed
    }

    /// Сколько часов смены попадает в ночное окно.
    func nightHours(nightStart: Int, nightEnd: Int) -> Double {
        guard isWorking else { return 0 }
        let duration = durationHours * 60
        guard duration > 0 else { return 0 }

        let start = Double(startMinutes)
        let end = start + duration
        let day = 24.0 * 60.0
        var span = Double(nightEnd - nightStart).truncatingRemainder(dividingBy: day)
        if span <= 0 { span += day }

        var total: Double = 0
        for offset in [-day, 0, day] {
            let windowStart = Double(nightStart) + offset
            let windowEnd = windowStart + span
            let overlap = min(end, windowEnd) - max(start, windowStart)
            if overlap > 0 { total += overlap }
        }

        return min(total, duration) / 60
    }
}
