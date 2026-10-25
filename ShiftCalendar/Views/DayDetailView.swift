import SwiftUI

struct DayDetailView: View {
    let date: Date

    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    @State private var note: String = ""
    @State private var hours: Double = 0
    @State private var didLoad = false
    @State private var editingType: ShiftType?

    private var currentType: ShiftType? {
        store.shiftType(for: date)
    }

    private var pay: DayPay? {
        store.pay(for: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    shiftSection
                    if let type = currentType, type.isWorking {
                        hoursSection(type: type)
                    }
                    if let pay = pay, !pay.isEmpty {
                        moneySection(pay: pay)
                    }
                    noteSection
                }
                .padding(16)
            }
            .background(Color.appGroupedBackground)
            .navigationTitle("День")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .sheet(item: $editingType) { type in
                ShiftTypeEditorView(type: type)
                    .environmentObject(store)
            }
            .onAppear {
                guard !didLoad else { return }
                note = store.note(for: date)
                hours = store.hours(for: date)
                didLoad = true
            }
            .onChange(of: note) { newValue in
                store.setNote(newValue, for: date)
            }
            .onChange(of: store.data.shiftTypes) { _ in
                if !store.hasHoursOverride(date) {
                    hours = store.hours(for: date)
                }
            }
        }
    }

    // MARK: - Заголовок

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Cal.dayTitle(date))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.appLabel)

            HStack(spacing: 6) {
                if let type = currentType {
                    ColorDot(color: type.color, size: 8)
                    Text(type.name)
                    Text("·")
                    Text(type.timeRangeText)
                    if type.isWorking {
                        Text("·")
                        Text(type.durationText)
                    }
                } else {
                    Text("Смена не назначена")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.appSecondaryLabel)

            if let pay = pay, pay.total > 0 {
                Text(Fmt.money(pay.total, currency: store.data.settings.currency))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appLabel)
            }
        }
    }

    // MARK: - Смена

    private var shiftSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Смена")
                    .font(.headline)
                    .foregroundStyle(Color.appLabel)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(store.data.shiftTypes) { type in
                        chipButton(
                            title: type.name,
                            subtitle: type.timeRangeText,
                            color: type.color,
                            selected: currentType?.id == type.id
                        ) {
                            store.setShift(type, for: date)
                            hours = store.hours(for: date)
                        }
                    }

                    chipButton(
                        title: "Без смены",
                        subtitle: "выходной",
                        color: Color.gray,
                        selected: store.isDayOff(date)
                    ) {
                        store.setShift(nil, for: date)
                        hours = 0
                    }
                }

                HStack(spacing: 14) {
                    if let type = currentType {
                        Button {
                            editingType = type
                        } label: {
                            Label("Изменить тип", systemImage: "slider.horizontal.3")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderless)
                    }

                    if store.hasOverride(date) {
                        Button {
                            store.usePattern(for: date)
                            hours = store.hours(for: date)
                        } label: {
                            Label("По циклу", systemImage: "arrow.uturn.backward")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Часы

    private func hoursSection(type: ShiftType) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Часы")
                        .font(.headline)
                        .foregroundStyle(Color.appLabel)
                    Spacer()
                    if store.hasHoursOverride(date) {
                        Button("Сброс") {
                            resetHours(type: type)
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }

                HStack(spacing: 14) {
                    stepButton(system: "minus", enabled: hours > 0.5) {
                        adjustHours(-0.5)
                    }

                    Text(Fmt.hours(hours))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.appLabel)
                        .frame(minWidth: 92)

                    stepButton(system: "plus", enabled: true) {
                        adjustHours(0.5)
                    }

                    Spacer(minLength: 0)
                }

                Text(store.hasHoursOverride(date)
                     ? "Факт \(Fmt.hours(hours)) · по графику \(type.durationText)"
                     : "По графику: \(type.durationText)")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryLabel)
            }
        }
    }

    // MARK: - Оплата

    private func moneySection(pay: DayPay) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Начисление")
                    .font(.headline)
                    .foregroundStyle(Color.appLabel)

                moneyRow("По смене", pay.base)
                if pay.nightBonus > 0 {
                    moneyRow("Ночные · \(Fmt.hours(pay.nightHours))", pay.nightBonus)
                }
                if pay.overtimeBonus > 0 {
                    moneyRow("Переработка · \(Fmt.hours(pay.overtimeHours))", pay.overtimeBonus)
                }

                Divider()

                HStack {
                    Text("Итого")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appLabel)
                    Spacer()
                    Text(Fmt.money(pay.total, currency: store.data.settings.currency))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appLabel)
                }
            }
        }
    }

    private func moneyRow(_ title: String, _ value: Double) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryLabel)
            Spacer()
            Text(Fmt.money(value, currency: store.data.settings.currency))
                .font(.subheadline)
                .foregroundStyle(Color.appLabel)
        }
    }

    // MARK: - Заметка

    private var noteSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Заметка")
                    .font(.headline)
                    .foregroundStyle(Color.appLabel)

                TextEditor(text: $note)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .overlay(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("Подмена, отпросился, переработка…")
                                .font(.subheadline)
                                .foregroundStyle(Color.appSecondaryLabel)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    // MARK: - Действия

    private func adjustHours(_ delta: Double) {
        let value = max(0, ((hours + delta) * 2).rounded() / 2)
        hours = value
        store.setHours(value, for: date)
    }

    private func resetHours(type: ShiftType) {
        hours = type.durationHours
        store.setHours(nil, for: date)
    }

    private func stepButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(enabled ? Color.appLabel : Color.appSecondaryLabel)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.appFill))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func chipButton(
        title: String,
        subtitle: String,
        color: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    ColorDot(color: color, size: 8)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(Color.appLabel)
                }
                Text(subtitle)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(Color.appSecondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? color.opacity(0.16) : Color.appFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
