import Foundation
import SwiftUI

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var data: ScheduleData

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let resolved = fileURL ?? ScheduleStore.defaultFileURL()
        self.fileURL = resolved
        if let stored = ScheduleStore.load(from: resolved) {
            self.data = stored
        } else {
            self.data = ScheduleData.makeDefault()
        }
    }

    // MARK: - Дни

    func shiftType(for date: Date) -> ShiftType? {
        data.shiftType(for: date)
    }

    func note(for date: Date) -> String {
        data.note(for: date)
    }

    func hasOverride(_ date: Date) -> Bool {
        data.hasShiftOverride(date)
    }

    func isDayOff(_ date: Date) -> Bool {
        data.isDayOff(date)
    }

    func hours(for date: Date) -> Double {
        data.hours(for: date)
    }

    func hasHoursOverride(_ date: Date) -> Bool {
        data.hasHoursOverride(date)
    }

    func pay(for date: Date) -> DayPay? {
        PayCalculator.dayPay(for: date, data: data)
    }

    /// Ручная смена. `nil` — принудительный выходной.
    func setShift(_ type: ShiftType?, for date: Date) {
        var patch = data.patch(for: date) ?? DayPatch()
        if let type = type {
            patch.shiftTypeID = type.id
            patch.isDayOff = false
        } else {
            patch.shiftTypeID = nil
            patch.isDayOff = true
            patch.hours = nil
        }
        write(patch, for: date)
    }

    /// Убрать ручную правку смены — день снова считается по циклу.
    func usePattern(for date: Date) {
        var patch = data.patch(for: date) ?? DayPatch()
        patch.shiftTypeID = nil
        patch.isDayOff = false
        patch.hours = nil
        write(patch, for: date)
    }

    func setHours(_ hours: Double?, for date: Date) {
        var patch = data.patch(for: date) ?? DayPatch()
        if let hours = hours {
            patch.hours = max(0, hours)
        } else {
            patch.hours = nil
        }
        write(patch, for: date)
    }

    func setNote(_ note: String, for date: Date) {
        var patch = data.patch(for: date) ?? DayPatch()
        patch.note = note
        write(patch, for: date)
    }

    private func write(_ patch: DayPatch, for date: Date) {
        let key = Cal.dayKey(date)
        if patch.isEmpty {
            data.patches.removeValue(forKey: key)
        } else {
            data.patches[key] = patch
        }
        persist()
    }

    // MARK: - Типы смен

    @discardableResult
    func addShiftType() -> ShiftType {
        let index = data.shiftTypes.count
        let type = ShiftType(
            name: "Смена \(index + 1)",
            short: "С\(index + 1)",
            colorHex: Palette.hexes[index % Palette.hexes.count],
            isWorking: true,
            startMinutes: 8 * 60,
            endMinutes: 20 * 60,
            pay: PayRule()
        )
        data.shiftTypes.append(type)
        persist()
        return type
    }

    func upsert(_ type: ShiftType) {
        if let index = data.shiftTypes.firstIndex(where: { $0.id == type.id }) {
            data.shiftTypes[index] = type
        } else {
            data.shiftTypes.append(type)
        }
        persist()
    }

    func deleteShiftType(_ id: UUID) {
        guard data.shiftTypes.count > 1 else { return }

        data.shiftTypes.removeAll { $0.id == id }

        guard let fallbackID = data.shiftTypes.first?.id else { return }
        for index in data.patterns.indices {
            data.patterns[index].cycle = data.patterns[index].cycle.map { $0 == id ? fallbackID : $0 }
        }

        var updates: [(String, DayPatch)] = []
        for (key, patch) in data.patches where patch.shiftTypeID == id {
            var value = patch
            value.shiftTypeID = nil
            value.isDayOff = true
            updates.append((key, value))
        }
        for (key, value) in updates {
            if value.isEmpty {
                data.patches.removeValue(forKey: key)
            } else {
                data.patches[key] = value
            }
        }

        persist()
    }

    // MARK: - Графики (циклы)

    func pattern(id: UUID) -> WorkPattern? {
        data.pattern(id: id)
    }

    @discardableResult
    func addPattern() -> WorkPattern {
        let source = data.activePattern
        let pattern = WorkPattern(
            name: "График \(data.patterns.count + 1)",
            anchorKey: source?.anchorKey ?? Cal.dayKey(Cal.startOfMonth(Date())),
            cycle: source?.cycle ?? [data.shiftTypes[0].id]
        )
        data.patterns.append(pattern)
        data.activePatternID = pattern.id
        persist()
        return pattern
    }

    func updatePattern(_ pattern: WorkPattern) {
        guard let index = data.patterns.firstIndex(where: { $0.id == pattern.id }) else { return }
        var value = pattern
        if value.cycle.isEmpty { value.cycle = [data.shiftTypes[0].id] }
        data.patterns[index] = value
        persist()
    }

    func setActivePattern(_ id: UUID) {
        guard data.patterns.contains(where: { $0.id == id }) else { return }
        data.activePatternID = id
        persist()
    }

    func deletePattern(_ id: UUID) {
        guard data.patterns.count > 1 else { return }
        data.patterns.removeAll { $0.id == id }
        if data.activePatternID == id, let first = data.patterns.first {
            data.activePatternID = first.id
        }
        persist()
    }

    func setPatternAnchor(patternID: UUID, date: Date) {
        guard let index = data.patterns.firstIndex(where: { $0.id == patternID }) else { return }
        data.patterns[index].anchorKey = Cal.dayKey(date)
        persist()
    }

    func setPatternName(patternID: UUID, name: String) {
        guard let index = data.patterns.firstIndex(where: { $0.id == patternID }) else { return }
        data.patterns[index].name = name
        persist()
    }

    func setCycleDay(patternID: UUID, index: Int, typeID: UUID) {
        guard let patternIndex = data.patterns.firstIndex(where: { $0.id == patternID }),
              data.patterns[patternIndex].cycle.indices.contains(index) else { return }
        data.patterns[patternIndex].cycle[index] = typeID
        persist()
    }

    func appendCycleDay(patternID: UUID) {
        guard let index = data.patterns.firstIndex(where: { $0.id == patternID }) else { return }
        let typeID = data.patterns[index].cycle.last ?? data.shiftTypes[0].id
        data.patterns[index].cycle.append(typeID)
        persist()
    }

    func removeCycleDay(patternID: UUID, index: Int) {
        guard let patternIndex = data.patterns.firstIndex(where: { $0.id == patternID }),
              data.patterns[patternIndex].cycle.count > 1,
              data.patterns[patternIndex].cycle.indices.contains(index) else { return }
        data.patterns[patternIndex].cycle.remove(at: index)
        persist()
    }

    // MARK: - Настройки

    func updateSettings(_ settings: AppSettings) {
        data.settings = settings
        persist()
    }

    // MARK: - Статистика

    func stats(for month: Date) -> MonthStats {
        data.stats(in: month)
    }

    // MARK: - Сброс и обмен данными

    func resetAll() {
        data = ScheduleData.makeDefault()
        persist()
    }

    func exportJSON() -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let raw = try encoder.encode(data)
            let url = ExportService.temporaryURL(name: "Смены-\(Cal.dayKey(Date())).json")
            try raw.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func importJSON(from url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let raw = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(ScheduleData.self, from: raw)
        data = decoded.sanitized()
        persist()
    }

    // MARK: - Хранение

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let raw = try encoder.encode(data)
            try raw.write(to: fileURL, options: .atomic)
        } catch {
            // Молча: данные остаются в памяти, приложение продолжает работать.
        }
    }

    private static func load(from url: URL) -> ScheduleData? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        guard let decoded = try? JSONDecoder().decode(ScheduleData.self, from: raw) else { return nil }
        return decoded.sanitized()
    }

    private static func defaultFileURL() -> URL {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.temporaryDirectory
        let directory = base.appendingPathComponent("ShiftCalendar", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("schedule.json")
    }
}
