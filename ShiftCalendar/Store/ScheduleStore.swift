import Foundation
import SwiftUI

struct TypeCount: Identifiable {
    let id: UUID
    let type: ShiftType
    let days: Int

    var hours: Double {
        Double(days) * type.durationHours
    }
}

struct MonthStats {
    var workingDays: Int = 0
    var offDays: Int = 0
    var totalHours: Double = 0
    var counts: [TypeCount] = []

    var hoursText: String {
        let rounded = totalHours.rounded()
        if abs(totalHours - rounded) < 0.01 {
            return "\(Int(rounded)) ч"
        }
        return String(format: "%.1f ч", totalHours)
    }
}

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

    /// Ручная смена. `nil` — принудительный выходной.
    func setShift(_ type: ShiftType?, for date: Date) {
        var patch = data.patch(for: date) ?? DayPatch()
        if let type = type {
            patch.shiftTypeID = type.id
            patch.isDayOff = false
        } else {
            patch.shiftTypeID = nil
            patch.isDayOff = true
        }
        write(patch, for: date)
    }

    /// Убрать ручную правку смены — день снова считается по циклу.
    func usePattern(for date: Date) {
        var patch = data.patch(for: date) ?? DayPatch()
        patch.shiftTypeID = nil
        patch.isDayOff = false
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
            endMinutes: 20 * 60
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
        data.pattern.cycle = data.pattern.cycle.map { $0 == id ? fallbackID : $0 }

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

    // MARK: - Цикл

    func setPatternAnchor(_ date: Date) {
        data.pattern.anchorKey = Cal.dayKey(date)
        persist()
    }

    func setCycleDay(_ index: Int, to typeID: UUID) {
        guard data.pattern.cycle.indices.contains(index) else { return }
        data.pattern.cycle[index] = typeID
        persist()
    }

    func appendCycleDay() {
        let typeID = data.pattern.cycle.last ?? data.shiftTypes[0].id
        data.pattern.cycle.append(typeID)
        persist()
    }

    func removeCycleDay(at index: Int) {
        guard data.pattern.cycle.count > 1, data.pattern.cycle.indices.contains(index) else { return }
        data.pattern.cycle.remove(at: index)
        persist()
    }

    // MARK: - Статистика

    func stats(for month: Date) -> MonthStats {
        let calendar = Cal.calendar
        let first = Cal.startOfMonth(month)
        guard let range = calendar.range(of: .day, in: .month, for: first) else {
            return MonthStats()
        }

        var result = MonthStats()
        var counter: [UUID: Int] = [:]

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: first) else { continue }
            guard let type = data.shiftType(for: date) else {
                result.offDays += 1
                continue
            }
            counter[type.id, default: 0] += 1
            if type.isWorking {
                result.workingDays += 1
                result.totalHours += type.durationHours
            } else {
                result.offDays += 1
            }
        }

        var counts: [TypeCount] = []
        for (id, days) in counter {
            guard let type = data.shiftType(id: id) else { continue }
            counts.append(TypeCount(id: id, type: type, days: days))
        }
        counts.sort { (lhs: TypeCount, rhs: TypeCount) -> Bool in
            if lhs.type.isWorking != rhs.type.isWorking { return lhs.type.isWorking }
            return lhs.type.name < rhs.type.name
        }
        result.counts = counts

        return result
    }

    // MARK: - Прочее

    func resetAll() {
        data = ScheduleData.makeDefault()
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
