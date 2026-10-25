import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ScheduleStore
    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.minutes") private var reminderMinutes = 20 * 60

    var body: some View {
        TabView {
            CalendarScreen()
                .tabItem { Label("Календарь", systemImage: "calendar") }

            StatsScreen()
                .tabItem { Label("Статистика", systemImage: "chart.bar.xaxis") }

            SettingsScreen()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .tint(Color.accentColor)
        .task {
            guard reminderEnabled else { return }
            let granted = await ReminderScheduler.requestAuthorizationIfNeeded()
            if granted {
                ReminderScheduler.schedule(data: store.data, minutes: reminderMinutes)
            }
        }
    }
}
