import SwiftUI

struct ShiftTypeEditorView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ShiftType

    init(type: ShiftType) {
        _draft = State(initialValue: type)
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Text("Такие дни считаются выходными и не дают часов в статистике.")
                    }
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
                        store.upsert(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
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
