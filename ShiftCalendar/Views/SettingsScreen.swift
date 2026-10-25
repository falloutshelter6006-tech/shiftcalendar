import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var nav: AppNavigation

    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.minutes") private var reminderMinutes = 20 * 60

    @State private var showResetConfirm = false
    @State private var showImporter = false
    @State private var shareItem: ShareItem?
    @State private var messageText = ""
    @State private var alertVisible = false

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
        return "\(short) (\(build))"
    }

    private var activePatternTitle: String {
        guard let pattern = store.data.activePattern else { return "—" }
        return "\(pattern.name) · \(pattern.cycle.count) дн."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("График") {
                    NavigationLink {
                        PatternsView()
                    } label: {
                        infoRow(title: "Мои графики", value: activePatternTitle)
                    }

                    NavigationLink {
                        ShiftTypesView()
                    } label: {
                        infoRow(title: "Типы смен", value: "\(store.data.shiftTypes.count)")
                    }
                }

                paymentSection

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

                exportSection

                Section("Данные") {
                    Button("Сбросить всё", role: .destructive) {
                        showResetConfirm = true
                    }
                }

                Section("О приложении") {
                    infoRow(title: "Версия", value: version)
                    infoRow(title: "Хранение", value: "Локально, на iPhone")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $shareItem) { item in
                ShareSheet(url: item.url)
                    .presentationDetents([.medium, .large])
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result)
            }
            .alert("Импорт", isPresented: $alertVisible) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(messageText)
            }
        }
        .alert("Сбросить всё?", isPresented: $showResetConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) {
                store.resetAll()
                applyReminders()
            }
        } message: {
            Text("Графики, типы смен, ставки и заметки вернутся к значениям по умолчанию.")
        }
    }

    // MARK: - Оплата

    private var paymentSection: some View {
        Section {
            HStack {
                Text("Валюта")
                    .foregroundStyle(Color.appLabel)
                Spacer(minLength: 8)
                TextField("₽", text: currencyBinding)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
            }

            Stepper(
                value: multiplierBinding,
                in: 1...3,
                step: 0.1,
                label: {
                    HStack {
                        Text("Множитель переработки")
                            .foregroundStyle(Color.appLabel)
                        Spacer(minLength: 8)
                        Text("×\(multiplierText)")
                            .foregroundStyle(Color.appSecondaryLabel)
                    }
                }
            )

            DatePicker(
                "Ночные с",
                selection: nightStartBinding,
                displayedComponents: .hourAndMinute
            )
            DatePicker(
                "Ночные до",
                selection: nightEndBinding,
                displayedComponents: .hourAndMinute
            )
        } header: {
            Text("Оплата")
        } footer: {
            Text("Ставки задаются у каждого типа смены. Ночные часы — пересечение смены с указанным окном. Переработка — часы сверх длительности смены.")
        }
    }

    private var multiplierText: String {
        String(format: "%.1f", store.data.settings.overtimeMultiplier)
            .replacingOccurrences(of: ".", with: ",")
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { store.data.settings.currency },
            set: { value in
                var settings = store.data.settings
                settings.currency = value
                store.updateSettings(settings)
            }
        )
    }

    private var multiplierBinding: Binding<Double> {
        Binding(
            get: { store.data.settings.overtimeMultiplier },
            set: { value in
                var settings = store.data.settings
                settings.overtimeMultiplier = min(3, max(1, (value * 10).rounded() / 10))
                store.updateSettings(settings)
            }
        )
    }

    private var nightStartBinding: Binding<Date> {
        Binding(
            get: { Cal.date(minutes: store.data.settings.nightStartMinutes) },
            set: { value in
                var settings = store.data.settings
                settings.nightStartMinutes = Cal.minutes(from: value)
                store.updateSettings(settings)
            }
        )
    }

    private var nightEndBinding: Binding<Date> {
        Binding(
            get: { Cal.date(minutes: store.data.settings.nightEndMinutes) },
            set: { value in
                var settings = store.data.settings
                settings.nightEndMinutes = Cal.minutes(from: value)
                store.updateSettings(settings)
            }
        )
    }

    // MARK: - Экспорт

    private var exportSection: some View {
        Section {
            Button {
                share(
                    ExportService.makeICS(data: store.data, month: nav.month),
                    failure: "Не удалось создать файл .ics"
                )
            } label: {
                Label("В календарь (.ics)", systemImage: "calendar.badge.plus")
            }

            Button {
                share(
                    ExportService.makePDF(data: store.data, month: nav.month),
                    failure: "Не удалось создать PDF"
                )
            } label: {
                Label("PDF на месяц", systemImage: "doc.richtext")
            }

            Button {
                share(store.exportJSON(), failure: "Не удалось сохранить JSON")
            } label: {
                Label("Резервная копия (.json)", systemImage: "square.and.arrow.up")
            }

            Button {
                showImporter = true
            } label: {
                Label("Загрузить копию (.json)", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Экспорт и бэкап")
        } footer: {
            Text("Экспорт берёт месяц, открытый в календаре: \(Cal.monthTitle(nav.month)). Файлы уходят в системное меню «Поделиться». JSON можно перенести на другое устройство через AirDrop или «Файлы».")
        }
    }

    private func share(_ url: URL?, failure: String) {
        guard let url = url else {
            presentMessage(failure)
            return
        }
        shareItem = ShareItem(url: url)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try store.importJSON(from: url)
                applyReminders()
                presentMessage("Данные загружены.")
            } catch {
                presentMessage("Не удалось прочитать файл: \(error.localizedDescription)")
            }
        case .failure(let error):
            presentMessage("Импорт не выполнен: \(error.localizedDescription)")
        }
    }

    private func presentMessage(_ text: String) {
        messageText = text
        alertVisible = true
    }

    // MARK: - Напоминания

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Cal.date(minutes: reminderMinutes) },
            set: { newValue in
                reminderMinutes = Cal.minutes(from: newValue)
            }
        )
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

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.appLabel)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(Color.appSecondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
