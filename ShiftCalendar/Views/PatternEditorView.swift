import SwiftUI

struct PatternEditorView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var anchor: Date = Cal.startOfDay(Date())

    var body: some View {
        List {
            Section {
                DatePicker(
                    "Первый день цикла",
                    selection: $anchor,
                    displayedComponents: .date
                )
                .onChange(of: anchor) { newValue in
                    store.setPatternAnchor(newValue)
                }
            } footer: {
                Text("От этой даты отсчитываются позиции цикла. Поменяй её, если график сдвинулся.")
            }

            Section {
                ForEach(Array(store.data.pattern.cycle.indices), id: \.self) { index in
                    cycleRow(index: index)
                }
                .onDelete(perform: deleteRows)
            } header: {
                Text("Цикл · \(store.data.pattern.cycle.count) дн.")
            } footer: {
                Text("Каждый день цикла — это тип смены. Например, 2/2: Д, Д, В, В. Свайп влево удаляет день.")
            }

            Section {
                Button {
                    store.appendCycleDay()
                } label: {
                    Label("Добавить день в цикл", systemImage: "plus.circle")
                }
            }

            Section("Предпросмотр · 14 дней") {
                previewStrip
            }
        }
        .navigationTitle("Цикл смен")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            anchor = Cal.startOfDay(store.data.pattern.anchorDate)
        }
    }

    private func cycleRow(index: Int) -> some View {
        HStack(spacing: 8) {
            Text("День \(index + 1)")
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryLabel)
                .frame(width: 66, alignment: .leading)

            Picker("Смена", selection: cycleBinding(index: index)) {
                ForEach(store.data.shiftTypes) { type in
                    Text(type.name).tag(type.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let id = currentCycleID(index: index), let type = store.data.shiftType(id: id) {
                ColorDot(color: type.color, size: 9)
                Text(type.timeRangeText)
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondaryLabel)
            }
        }
    }

    private func currentCycleID(index: Int) -> UUID? {
        let cycle = store.data.pattern.cycle
        guard cycle.indices.contains(index) else { return nil }
        return cycle[index]
    }

    private func cycleBinding(index: Int) -> Binding<UUID> {
        Binding(
            get: {
                if let id = currentCycleID(index: index) { return id }
                return store.data.shiftTypes[0].id
            },
            set: { newValue in
                store.setCycleDay(index, to: newValue)
            }
        )
    }

    private func deleteRows(_ offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            store.removeCycleDay(at: index)
        }
    }

    private var previewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<14, id: \.self) { offset in
                    previewCell(offset: offset)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func previewCell(offset: Int) -> some View {
        let date = Cal.addDays(offset, to: Cal.startOfDay(Date()))
        let type = store.data.shiftType(for: date)
        let isWorking = type?.isWorking ?? false
        let fill = type?.color ?? Color.gray

        return VStack(spacing: 3) {
            Text(Cal.weekdayShort[Cal.weekdayIndex(date)])
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.appSecondaryLabel)

            Text("\(Cal.dayNumber(date))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.appLabel)

            Text(type?.chipText ?? "—")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isWorking ? Color.white : Color.appSecondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 36, height: 16)
                .background(
                    Capsule()
                        .fill(isWorking ? fill : Color.appFill)
                )
        }
        .frame(width: 44)
    }
}
