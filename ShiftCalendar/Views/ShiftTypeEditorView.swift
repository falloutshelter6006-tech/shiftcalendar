import SwiftUI
import UIKit

struct ShiftTypeEditorView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ShiftType
    @State private var pay: PayRule

    init(type: ShiftType) {
        _draft = State(initialValue: type)
        _pay = State(initialValue: type.payRule)
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currency: String {
        store.data.settings.currency
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Дневная", text: $draft.name)
                    TextField("Коротко, 1–2 символа", text: $draft.short)
                }

                Section("Цвет") {
                    colorGrid
                        .padding(.vertical, 4)
                }

                Section {
                    Toggle("Рабочая смена", isOn: $draft.isWorking)

                    if draft.isWorking {
                        DatePicker(
                            "Начало",
                            selection: timeBinding(\.startMinutes),
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "Конец",
                            selection: timeBinding(\.endMinutes),
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Время")
                } footer: {
                    if draft.isWorking {
                        Text("Длительность: \(draft.durationText). Если конец раньше начала, смена считается ночной и переходит через полночь.")
                    } else {
                        Text("Такие дни считаются выходными и не дают часов и денег в статистике.")
                    }
                }

                if draft.isWorking {
                    paySection
                }

                Section {
                    preview
                }
            }
            .navigationTitle("Тип смены")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var value = draft
                        value.pay = pay
                        store.upsert(value)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Оплата

    private var paySection: some View {
        Section {
            Picker("Формат оплаты", selection: $pay.mode) {
                ForEach(PayMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if pay.mode == .hourly {
                rateField(
                    title: "Ставка за час",
                    value: $pay.hourlyRate
                )

                HStack {
                    Text("Надбавка за ночные")
                        .foregroundStyle(Color.appLabel)
                    Spacer(minLength: 8)
                    TextField("0", value: $pay.nightBonusPercent, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                    Text("%")
                        .foregroundStyle(Color.appSecondaryLabel)
                }
            } else {
                rateField(
                    title: "Ставка за смену",
                    value: $pay.shiftRate
                )
            }
        } header: {
            Text("Оплата")
        } footer: {
            Text(payFooter)
        }
    }

    private func rateField(title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.appLabel)
            Spacer(minLength: 8)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(currency)
                .foregroundStyle(Color.appSecondaryLabel)
        }
    }

    private var payFooter: String {
        let settings = store.data.settings
        let night = draft.nightHours(
            nightStart: settings.nightStartMinutes,
            nightEnd: settings.nightEndMinutes
        )
        let window = "\(Cal.timeText(settings.nightStartMinutes))–\(Cal.timeText(settings.nightEndMinutes))"

        switch pay.mode {
        case .hourly:
            let base = draft.durationHours * pay.hourlyRate
            let bonus = night * pay.hourlyRate * pay.nightBonusPercent / 100
            var text = "За смену: \(Fmt.money(base, currency: currency)) по ставке \(Fmt.rate(pay.hourlyRate, currency: currency))/ч."
            if pay.nightBonusPercent > 0, night > 0 {
                text += " Ночных \(Fmt.hours(night)) с \(window): +\(Fmt.money(bonus, currency: currency))."
            }
            return text
        case .perShift:
            return "За смену: \(Fmt.money(pay.shiftRate, currency: currency)). Надбавка за ночные считается только при оплате за час."
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 10)], spacing: 10) {
            ForEach(Palette.hexes, id: \.self) { hex in
                Button {
                    draft.colorHex = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.appLabel.opacity(draft.colorHex == hex ? 0.9 : 0), lineWidth: 2)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(draft.isWorking ? draft.color : Color.appFill)
                .frame(width: 34, height: 34)
                .overlay(
                    Text(draft.chipText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(draft.isWorking ? Color.white : Color.appSecondaryLabel)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.name.isEmpty ? "Без названия" : draft.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appLabel)
                Text("\(draft.timeRangeText) · \(draft.durationText)")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryLabel)
            }
        }
        .padding(.vertical, 2)
    }

    private func timeBinding(_ keyPath: WritableKeyPath<ShiftType, Int>) -> Binding<Date> {
        Binding(
            get: { Cal.date(minutes: draft[keyPath: keyPath]) },
            set: { newValue in
                draft[keyPath: keyPath] = Cal.minutes(from: newValue)
            }
        )
    }
}
