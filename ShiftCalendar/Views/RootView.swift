import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var nav: AppNavigation
    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.minutes") private var reminderMinutes = 20 * 60

    var body: some View {
        TabView(selection: $nav.tab) {
            CalendarScreen()
                .tag(0)
                .tabItem { Label("Календарь", systemImage: "calendar") }

            YearScreen()
                .tag(1)
                .tabItem { Label("Год", systemImage: "square.grid.3x3") }

            StatsScreen()
                .tag(2)
                .tabItem { Label("Статистика", systemImage: "chart.bar.xaxis") }

            SettingsScreen()
                .tag(3)
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
