import Foundation

/// Всё состояние приложения. Хранится одним JSON-файлом.
struct ScheduleData: Codable, Equatable {
    var version: Int = 2
    var shiftTypes: [ShiftType]
    var patterns: [WorkPattern]
    var activePatternID: UUID
    var patches: [String: DayPatch]
    var settings: AppSettings

    static func makeDefault() -> ScheduleData {
        let day = ShiftType(
            name: "Дневная",
            short: "Д",
            colorHex: Palette.hexes[0],
            isWorking: true,
            startMinutes: 8 * 60,
            endMinutes: 20 * 60,
            pay: PayRule(mode: .hourly, hourlyRate: 400, shiftRate: 0, nightBonusPercent: 0)
        )
        let night = ShiftType(
            name: "Ночная",
            short: "Н",
            colorHex: Palette.hexes[2],
            isWorking: true,
            startMinutes: 20 * 60,
            endMinutes: 8 * 60,
            pay: PayRule(mode: .hourly, hourlyRate: 400, shiftRate: 0, nightBonusPercent: 40)
        )
        let off = ShiftType(
            name: "Выходной",
            short: "В",
            colorHex: Palette.hexes[9],
            isWorking: false,
            startMinutes: 0,
            endMinutes: 0,
            pay: nil
        )

        let pattern = WorkPattern(
            name: "Основной 2/2",
            anchorKey: Cal.dayKey(Cal.startOfMonth(Date())),
            cycle: [day.id, day.id, off.id, off.id]
        )

        return ScheduleData(
            version: 2,
            shiftTypes: [day, night, off],
            patterns: [pattern],
            activePatternID: pattern.id,
            patches: [:],
            settings: AppSettings()
        )
    }
}

// MARK: - Кодирование с миграцией из версии 1

extension ScheduleData {
    private enum CodingKeys: String, CodingKey {
        case version
        case shiftTypes
        case patterns
        case activePatternID
        case patches
        case settings
    }

    private enum LegacyKeys: String, CodingKey {
        case pattern
    }

    private struct LegacyPattern: Codable {
        var anchorKey: String
        var cycle: [UUID]
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ScheduleData.makeDefault()

        version = (try? container.decode(Int.self, forKey: .version)) ?? 1
        shiftTypes = (try? container.decode([ShiftType].self, forKey: .shiftTypes)) ?? fallback.shiftTypes
        patches = (try? container.decode([String: DayPatch].self, forKey: .patches)) ?? [:]
        settings = (try? container.decode(AppSettings.self, forKey: .settings)) ?? AppSettings()

        if let saved = try? container.decode([WorkPattern].self, forKey: .patterns), !saved.isEmpty {
            patterns = saved
            activePatternID = (try? container.decode(UUID.self, forKey: .activePatternID)) ?? saved[0].id
        } else if let legacyContainer = try? decoder.container(keyedBy: LegacyKeys.self),
                  let legacy = try? legacyContainer.decode(LegacyPattern.self, forKey: .pattern) {
            let migrated = WorkPattern(
                name: "Основной",
                anchorKey: legacy.anchorKey,
                cycle: legacy.cycle
            )
            patterns = [migrated]
            activePatternID = migrated.id
        } else {
            patterns = fallback.patterns
            activePatternID = fallback.activePatternID
        }

        self = sanitized()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(shiftTypes, forKey: .shiftTypes)
        try container.encode(patterns, forKey: .patterns)
        try container.encode(activePatternID, forKey: .activePatternID)
        try container.encode(patches, forKey: .patches)
        try container.encode(settings, forKey: .settings)
    }
}

// MARK: - Чтение состояния

extension ScheduleData {
    var activePattern: WorkPattern? {
        patterns.first { $0.id == activePatternID } ?? patterns.first
    }

    func pattern(id: UUID) -> WorkPattern? {
        patterns.first { $0.id == id }
    }

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

    /// Смена строго по активному циклу, без ручных правок.
    func patternShiftType(for date: Date) -> ShiftType? {
        guard let pattern = activePattern else { return nil }
        return patternShiftType(for: date, in: pattern)
    }

    func patternShiftType(for date: Date, in pattern: WorkPattern) -> ShiftType? {
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

    /// Фактические часы: из правки дня или из типа смены.
    func hours(for date: Date) -> Double {
        if let saved = patch(for: date)?.hours { return saved }
        return shiftType(for: date)?.durationHours ?? 0
    }

    func hasHoursOverride(_ date: Date) -> Bool {
        patch(for: date)?.hours != nil
    }

    /// Дни месяца по порядку.
    func days(in month: Date) -> [Date] {
        let calendar = Cal.calendar
        let first = Cal.startOfMonth(month)
        guard let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        var result: [Date] = []
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: first) {
                result.append(date)
            }
        }
        return result
    }

    /// Приводит данные в согласованное состояние.
    func sanitized() -> ScheduleData {
        var copy = self

        if copy.shiftTypes.isEmpty {
            copy.shiftTypes = ScheduleData.makeDefault().shiftTypes
        }

        let existingIDs = Set(copy.shiftTypes.map { $0.id })

        if copy.patterns.isEmpty {
            copy.patterns = ScheduleData.makeDefault().patterns
        }

        for index in copy.patterns.indices {
            copy.patterns[index].cycle = copy.patterns[index].cycle.filter { existingIDs.contains($0) }
            if copy.patterns[index].cycle.isEmpty {
                copy.patterns[index].cycle = [copy.shiftTypes[0].id]
            }
            if Cal.date(fromKey: copy.patterns[index].anchorKey) == nil {
                copy.patterns[index].anchorKey = Cal.dayKey(Cal.startOfMonth(Date()))
            }
            if copy.patterns[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.patterns[index].name = "График"
            }
        }

        if !copy.patterns.contains(where: { $0.id == copy.activePatternID }) {
            copy.activePatternID = copy.patterns[0].id
        }

        var cleanedPatches: [String: DayPatch] = [:]
        for (key, patch) in copy.patches {
            var value = patch
            if let id = value.shiftTypeID, !existingIDs.contains(id) {
                value.shiftTypeID = nil
                value.isDayOff = true
            }
            if let hours = value.hours, hours < 0 {
                value.hours = nil
            }
            if !value.isEmpty {
                cleanedPatches[key] = value
            }
        }
        copy.patches = cleanedPatches

        copy.version = 2
        return copy
    }
}
