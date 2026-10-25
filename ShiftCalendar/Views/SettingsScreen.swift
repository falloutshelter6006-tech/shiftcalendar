import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var store: ScheduleStore

    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.minutes") private var reminderMinutes = 20 * 60

    @State private var showResetConfirm = false

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("График") {
                    NavigationLink {
                        PatternEditorView()
                    } label: {
                        infoRow(title: "Цикл смен", value: patternSummary)
                    }

                    NavigationLink {
                        ShiftTypesView()
                    } label: {
                        infoRow(title: "Типы смен", value: "\(store.data.shiftTypes.count)")
                    }
                }

                Section {
                    Toggle("Напоминать о смене", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _ in
                            applyReminders()
                        }

                    if reminderEnabled {
                        DatePicker(
                            "Время напоминания",
                            selection: reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderMinutes) { _ in
                            applyReminders()
                        }
                    }
                } header: {
                    Text("Напоминания")
                } footer: {
                    Text("Уведомление приходит в выбранное время в дни рабочих смен. Работает без интернета.")
                }

                Section("Данные") {
                    Button("Сбросить настройки графика", role: .destructive) {
                        showResetConfirm = true
                    }
                }

                Section("О приложении") {
                    infoRow(title: "Версия", value: version)
                    infoRow(title: "Хранение", value: "Локально, на iPhone")
                }
            }
            .navigationTitle("Настройки")
            .alert("Сбросить всё?", isPresented: $showResetConfirm) {
                Button("Отмена", role: .cancel) {}
                Button("Сбросить", role: .destructive) {
                    store.resetAll()
                    applyReminders()
                }
            } message: {
                Text("Цикл, типы смен и заметки вернутся к значениям по умолчанию.")
            }
        }
    }

    private var patternSummary: String {
        let cycle = store.data.pattern.cycle
        var working = 0
        for id in cycle {
            if let type = store.data.shiftType(id: id), type.isWorking {
                working += 1
            }
        }
        let off = cycle.count - working
        return "\(working)/\(off) · \(cycle.count) дн."
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Cal.date(minutes: reminderMinutes) },
            set: { newValue in
                reminderMinutes = Cal.minutes(from: newValue)
            }
        )
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.appLabel)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(Color.appSecondaryLabel)
        }
    }

    private func applyReminders() {
        guard reminderEnabled else {
            ReminderScheduler.cancelAll()
            return
        }
        let data = store.data
        let minutes = reminderMinutes
        Task {
            let granted = await ReminderScheduler.requestAuthorizationIfNeeded()
            guard granted else { return }
            ReminderScheduler.schedule(data: data, minutes: minutes)
        }
    }
}
