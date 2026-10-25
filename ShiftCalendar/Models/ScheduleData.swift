import Foundation

/// Всё состояние приложения. Хранится одним JSON-файлом.
struct ScheduleData: Codable, Equatable {
    var version: Int = 1
    var shiftTypes: [ShiftType]
    var pattern: ShiftPattern
    var patches: [String: DayPatch]

    static func makeDefault() -> ScheduleData {
        let day = ShiftType(
            name: "Дневная",
            short: "Д",
            colorHex: Palette.hexes[0],
            isWorking: true,
            startMinutes: 8 * 60,
            endMinutes: 20 * 60
        )
        let night = ShiftType(
            name: "Ночная",
            short: "Н",
            colorHex: Palette.hexes[2],
            isWorking: true,
            startMinutes: 20 * 60,
            endMinutes: 8 * 60
        )
        let off = ShiftType(
            name: "Выходной",
            short: "В",
            colorHex: Palette.hexes[9],
            isWorking: false,
            startMinutes: 0,
            endMinutes: 0
        )
        let anchor = Cal.startOfMonth(Date())
        return ScheduleData(
            version: 1,
            shiftTypes: [day, night, off],
            pattern: ShiftPattern(
                anchorKey: Cal.dayKey(anchor),
                cycle: [day.id, day.id, off.id, off.id]
            ),
            patches: [:]
        )
    }
}

extension ScheduleData {
    func patch(for date: Date) -> DayPatch? {
        patches[Cal.dayKey(date)]
    }

    /// Смена на конкретный день с учётом ручных правок.
    func shiftType(for date: Date) -> ShiftType? {
        if let patch = patch(for: date) {
            if patch.isDayOff { return nil }
            if let id = patch.shiftTypeID, let type = shiftType(id: id) {
                return type
            }
        }
        return patternShiftType(for: date)
    }

    /// Смена строго по циклу, без ручных правок.
    func patternShiftType(for date: Date) -> ShiftType? {
        guard !pattern.cycle.isEmpty else { return nil }
        let days = Cal.calendar.dateComponents(
            [.day],
            from: Cal.startOfDay(pattern.anchorDate),
            to: Cal.startOfDay(date)
        ).day ?? 0

        var index = days % pattern.cycle.count
        if index < 0 { index += pattern.cycle.count }

        return shiftType(id: pattern.cycle[index])
    }

    func shiftType(id: UUID) -> ShiftType? {
        shiftTypes.first { $0.id == id }
    }

    func hasShiftOverride(_ date: Date) -> Bool {
        patch(for: date)?.hasShiftChange ?? false
    }

    func isDayOff(_ date: Date) -> Bool {
        patch(for: date)?.isDayOff ?? false
    }

    func note(for date: Date) -> String {
        patch(for: date)?.note ?? ""
    }

    /// Приводит данные в согласованное состояние: цикл и правки ссылаются
    /// только на существующие типы смен.
    func sanitized() -> ScheduleData {
        var copy = self

        if copy.shiftTypes.isEmpty {
            copy.shiftTypes = ScheduleData.makeDefault().shiftTypes
        }

        let existingIDs = Set(copy.shiftTypes.map { $0.id })
        copy.pattern.cycle = copy.pattern.cycle.filter { existingIDs.contains($0) }

        if copy.pattern.cycle.isEmpty {
            copy.pattern.cycle = [copy.shiftTypes[0].id]
        }

        if Cal.date(fromKey: copy.pattern.anchorKey) == nil {
            copy.pattern.anchorKey = Cal.dayKey(Cal.startOfMonth(Date()))
        }

        var cleanedPatches: [String: DayPatch] = [:]
        for (key, patch) in copy.patches {
            var value = patch
            if let id = value.shiftTypeID, !existingIDs.contains(id) {
                value.shiftTypeID = nil
                value.isDayOff = true
            }
            if !value.isEmpty {
                cleanedPatches[key] = value
            }
        }
        copy.patches = cleanedPatches

        return copy
    }
}
