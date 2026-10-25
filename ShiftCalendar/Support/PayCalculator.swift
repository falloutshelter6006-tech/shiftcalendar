import Foundation

/// Расчёт оплаты за один день.
struct DayPay: Equatable {
    var hours: Double = 0
    var nominalHours: Double = 0
    var nightHours: Double = 0
    var overtimeHours: Double = 0
    var base: Double = 0
    var nightBonus: Double = 0
    var overtimeBonus: Double = 0

    var total: Double {
        base + nightBonus + overtimeBonus
    }

    var isEmpty: Bool {
        total == 0 && hours == 0
    }
}

enum PayCalculator {
    static func dayPay(for date: Date, data: ScheduleData) -> DayPay? {
        guard let type = data.shiftType(for: date), type.isWorking else { return nil }

        let rule = type.payRule
        let nominal = type.durationHours
        guard nominal > 0 else { return nil }

        let hours = max(0, data.patch(for: date)?.hours ?? nominal)
        var pay = DayPay()
        pay.hours = hours
        pay.nominalHours = nominal

        switch rule.mode {
        case .hourly:
            pay.base = hours * rule.hourlyRate
        case .perShift:
            pay.base = rule.shiftRate
        }

        let nightNominal = type.nightHours(
            nightStart: data.settings.nightStartMinutes,
            nightEnd: data.settings.nightEndMinutes
        )
        let scale = nominal > 0 ? hours / nominal : 1
        pay.nightHours = nightNominal * scale

        if rule.mode == .hourly, rule.hourlyRate > 0 {
            if rule.nightBonusPercent > 0 {
                pay.nightBonus = pay.nightHours * rule.hourlyRate * rule.nightBonusPercent / 100
            }
            let overtime = max(0, hours - nominal)
            let multiplier = max(1, data.settings.overtimeMultiplier)
            if overtime > 0, multiplier > 1 {
                pay.overtimeHours = overtime
                pay.overtimeBonus = overtime * rule.hourlyRate * (multiplier - 1)
            }
        }

        return pay
    }
}
