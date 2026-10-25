import SwiftUI

struct ShiftTypesView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var editing: ShiftType?

    private var canDelete: Bool {
        store.data.shiftTypes.count > 1
    }

    var body: some View {
        List {
            Section {
                ForEach(store.data.shiftTypes) { type in
                    Button {
                        editing = type
                    } label: {
                        row(for: type)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteRows)
            } footer: {
                Text(canDelete
                     ? "Свайп влево удаляет тип. Дни цикла и отметки в календаре перейдут на первый тип."
                     : "Нельзя удалить последний тип смены.")
            }

            Section {
                Button {
                    editing = store.addShiftType()
                } label: {
                    Label("Добавить тип смены", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Типы смен")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { type in
            ShiftTypeEditorView(type: type)
                .environmentObject(store)
        }
    }

    private func row(for type: ShiftType) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(type.isWorking ? type.color : Color.appFill)
                .frame(width: 34, height: 34)
                .overlay(
                    Text(type.chipText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(type.isWorking ? Color.white : Color.appSecondaryLabel)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(type.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appLabel)
                Text("\(type.timeRangeText) · \(type.durationText)")
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryLabel)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appSecondaryLabel.opacity(0.6))
        }
        .contentShape(Rectangle())
    }

    private func deleteRows(_ offsets: IndexSet) {
        guard canDelete else { return }
        let types = store.data.shiftTypes
        for index in offsets {
            guard types.indices.contains(index) else { continue }
            store.deleteShiftType(types[index].id)
        }
    }
}
