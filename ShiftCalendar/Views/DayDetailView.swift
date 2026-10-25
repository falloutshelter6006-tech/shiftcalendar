import SwiftUI

struct DayDetailView: View {
    let date: Date

    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    @State private var note: String = ""
    @State private var didLoadNote = false

    private var currentType: ShiftType? {
        store.shiftType(for: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    shiftSection
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
            .onAppear {
                guard !didLoadNote else { return }
                note = store.note(for: date)
                didLoadNote = true
            }
            .onChange(of: note) { newValue in
                store.setNote(newValue, for: date)
            }
        }
    }

    // MARK: - Секции

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
        }
    }

    private var shiftSection: some View {
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
                    }
                }

                chipButton(
                    title: "Без смены",
                    subtitle: "выходной",
                    color: Color.gray,
                    selected: store.isDayOff(date)
                ) {
                    store.setShift(nil, for: date)
                }
            }

            if store.hasOverride(date) {
                Button {
                    store.usePattern(for: date)
                } label: {
                    Label("Вернуть по циклу", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Заметка")
                .font(.headline)
                .foregroundStyle(Color.appLabel)

            TextEditor(text: $note)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.appCellBackground)
                )
                .overlay(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("Подмена, отпросился, переработка…")
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryLabel)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Кнопка-чип

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
