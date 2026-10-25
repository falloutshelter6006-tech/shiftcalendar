import Foundation

/// Итоги по одному типу смен за месяц.
struct TypeCount: Identifiable {
    let id: UUID
    let type: ShiftType
    let days: Int
    let hours: Double
    let pay: Double
}

/// Итоги месяца: смены, часы, деньги.
struct MonthStats {
    var workingDays: Int = 0
    var offDays: Int = 0
    var totalHours: Double = 0
    var nightHours: Double = 0
    var overtimeHours: Double = 0
    var totalPay: Double = 0
    var counts: [TypeCount] = []

    var hoursText: String {
        Fmt.hours(totalHours)
    }
}

extension ScheduleData {
    func stats(in month: Date) -> MonthStats {
        var result = MonthStats()
        var days: [UUID: Int] = [:]
        var hours: [UUID: Double] = [:]
        var money: [UUID: Double] = [:]

        for date in self.days(in: month) {
            guard let type = shiftType(for: date) else {
                result.offDays += 1
                continue
            }

            let pay = PayCalculator.dayPay(for: date, data: self)
            let dayHours = pay?.hours ?? self.hours(for: date)

            days[type.id, default: 0] += 1
            hours[type.id, default: 0] += dayHours
            money[type.id, default: 0] += pay?.total ?? 0

            if type.isWorking {
                result.workingDays += 1
                result.totalHours += dayHours
                result.totalPay += pay?.total ?? 0
                result.nightHours += pay?.nightHours ?? 0
                result.overtimeHours += pay?.overtimeHours ?? 0
            } else {
                result.offDays += 1
            }
        }

        var counts: [TypeCount] = []
        for (id, count) in days {
            guard let type = shiftType(id: id) else { continue }
            counts.append(
                TypeCount(
                    id: id,
                    type: type,
                    days: count,
                    hours: hours[id] ?? 0,
                    pay: money[id] ?? 0
                )
            )
        }
        counts.sort { (lhs: TypeCount, rhs: TypeCount) -> Bool in
            if lhs.type.isWorking != rhs.type.isWorking { return lhs.type.isWorking }
            return lhs.type.name < rhs.type.name
        }
        result.counts = counts

        return result
    }
}
