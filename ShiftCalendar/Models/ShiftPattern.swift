import Foundation

/// Циклический график: последовательность типов смен, которая повторяется
/// от даты-якоря (первый день цикла). Графиков может быть несколько.
struct WorkPattern: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
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
    /// Фактически отработанные часы (если отличаются от смены по графику).
    var hours: Double?
    var note: String = ""

    var isEmpty: Bool {
        !isDayOff
            && shiftTypeID == nil
            && hours == nil
            && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasShiftChange: Bool {
        isDayOff || shiftTypeID != nil
    }
}

/// Настройки оплаты и отображения.
struct AppSettings: Codable, Hashable {
    var currency: String = "₽"
    /// Коэффициент оплаты переработки (часы сверх смены).
    var overtimeMultiplier: Double = 1.5
    var nightStartMinutes: Int = 22 * 60
    var nightEndMinutes: Int = 6 * 60
}
