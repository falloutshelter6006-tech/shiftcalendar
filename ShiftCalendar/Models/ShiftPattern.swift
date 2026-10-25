import Foundation

/// Циклический график: последовательность типов смен, которая повторяется
/// от даты-якоря (первый день цикла).
struct ShiftPattern: Codable, Hashable {
    var anchorKey: String
    var cycle: [UUID]

    var anchorDate: Date {
        Cal.date(fromKey: anchorKey) ?? Cal.startOfDay(Date())
    }

    var length: Int {
        cycle.count
    }
}

/// Ручная правка конкретного дня поверх цикла.
struct DayPatch: Codable, Hashable {
    /// День принудительно помечен как выходной (перекрывает цикл).
    var isDayOff: Bool = false
    /// Смена, назначенная вручную вместо цикловой.
    var shiftTypeID: UUID?
    var note: String = ""

    var isEmpty: Bool {
        !isDayOff && shiftTypeID == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasShiftChange: Bool {
        isDayOff || shiftTypeID != nil
    }
}
