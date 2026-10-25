import Foundation
import UserNotifications

/// Локальные напоминания о смене. Никакого сервера не нужно.
enum ReminderScheduler {
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Ставит напоминания на 30 дней вперёд для всех рабочих смен.
    static func schedule(data: ScheduleData, minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Cal.calendar
        let today = Cal.startOfDay(Date())

        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            guard let type = data.shiftType(for: day), type.isWorking else { continue }

            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = minutes / 60
            comps.minute = minutes % 60

            guard let fireDate = calendar.date(from: comps), fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Смена сегодня"
            content.body = "\(type.name), \(type.timeRangeText)"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "shift-reminder-" + Cal.dayKey(day),
                content: content,
                trigger: trigger
            )
            center.add(request, withCompletionHandler: nil)
        }
    }
}
