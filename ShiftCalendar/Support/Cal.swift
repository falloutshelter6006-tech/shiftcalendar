import Foundation

/// Одна ячейка сетки календаря. `date == nil` — пустая ячейка (сдвиг до начала месяца).
struct CalendarCell: Identifiable {
    let id: Int
    let date: Date?
    let isWeekend: Bool
}

/// Календарная математика и форматирование дат. Всё считается в локальной таймзоне,
/// неделя начинается с понедельника.
enum Cal {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale(identifier: "ru_RU")
        return c
    }

    static let weekdayShort = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func startOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    static func addMonths(_ value: Int, to date: Date) -> Date {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: date) else { return date }
        return startOfMonth(shifted)
    }

    static func addDays(_ value: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: value, to: date) ?? date
    }

    static func monthTitle(_ date: Date) -> String {
        let text = monthFormatter.string(from: date)
        return String(text.prefix(1)).uppercased() + String(text.dropFirst())
    }

    static func dayTitle(_ date: Date) -> String {
        let text = dayFormatter.string(from: date)
        return String(text.prefix(1)).uppercased() + String(text.dropFirst())
    }

    static func shortDayTitle(_ date: Date) -> String {
        shortDayFormatter.string(from: date)
    }

    static func dayNumber(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    static func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    static func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    /// Индекс дня недели, где понедельник = 0.
    static func weekdayIndex(_ date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// Ключ дня в формате "2026-10-25" (локальная дата, без времени).
    static func dayKey(_ date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 1970, comps.month ?? 1, comps.day ?? 1)
    }

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        return calendar.date(from: comps)
    }

    static func cells(for month: Date) -> [CalendarCell] {
        let cal = calendar
        let first = startOfMonth(month)
        guard let range = cal.range(of: .day, in: .month, for: first) else { return [] }

        let leading = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        var result: [CalendarCell] = []
        var index = 0

        while index < leading {
            result.append(CalendarCell(id: index, date: nil, isWeekend: false))
            index += 1
        }

        for day in range {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: first) else { continue }
            result.append(CalendarCell(id: index, date: date, isWeekend: isWeekend(date)))
            index += 1
        }

        while result.count % 7 != 0 {
            result.append(CalendarCell(id: index, date: nil, isWeekend: false))
            index += 1
        }

        return result
    }

    // MARK: - Время

    static func minutes(from date: Date) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    static func date(minutes: Int) -> Date {
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    static func timeText(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }
}
