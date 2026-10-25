import SwiftUI

struct PatternEditorView: View {
    let patternID: UUID

    @EnvironmentObject private var store: ScheduleStore
    @State private var name: String = ""
    @State private var anchor: Date = Cal.startOfDay(Date())
    @State private var didLoad = false

    private var pattern: WorkPattern? {
        store.pattern(id: patternID)
    }

    var body: some View {
        List {
            if let pattern = pattern {
                Section {
                    TextField("Название графика", text: $name)
                        .onChange(of: name) { newValue in
                            store.setPatternName(patternID: patternID, name: newValue)
                        }

                    DatePicker(
                        "Первый день цикла",
                        selection: $anchor,
                        displayedComponents: .date
                    )
                    .onChange(of: anchor) { newValue in
                        store.setPatternAnchor(patternID: patternID, date: newValue)
                    }

                    if pattern.id != store.data.activePatternID {
                        Button {
                            store.setActivePattern(pattern.id)
                        } label: {
                            Label("Сделать активным", systemImage: "checkmark.circle")
                        }
                    }
                } header: {
                    Text("График")
                } footer: {
                    Text("От даты-якоря отсчитываются позиции цикла. Сдвинь её, если график поменялся.")
                }

                Section {
                    ForEach(Array(pattern.cycle.indices), id: \.self) { index in
                        cycleRow(index: index)
                    }
                    .onDelete { offsets in
                        deleteRows(offsets)
                    }
                } header: {
                    Text("Цикл · \(pattern.cycle.count) дн.")
                } footer: {
                    Text("Каждый день цикла — тип смены. Например, 2/2: Д, Д, В, В. Свайп влево удаляет день.")
                }

                Section {
                    Button {
                        store.appendCycleDay(patternID: patternID)
                    } label: {
                        Label("Добавить день в цикл", systemImage: "plus.circle")
                    }
                }

                Section("Предпросмотр · 14 дней") {
                    previewStrip(pattern: pattern)
                }
            } else {
                Text("График не найден")
                    .foregroundStyle(Color.appSecondaryLabel)
            }
        }
        .navigationTitle(name.isEmpty ? "График" : name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadIfNeeded()
        }
    }

    // MARK: - Строка цикла

    private func cycleRow(index: Int) -> some View {
        HStack(spacing: 8) {
            Text("День \(index + 1)")
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryLabel)
                .frame(width: 64, alignment: .leading)

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
        guard let pattern = pattern, pattern.cycle.indices.contains(index) else { return nil }
        return pattern.cycle[index]
    }

    private func cycleBinding(index: Int) -> Binding<UUID> {
        let fallback = store.data.shiftTypes.first?.id ?? UUID()
        return Binding(
            get: { currentCycleID(index: index) ?? fallback },
            set: { newValue in
                store.setCycleDay(patternID: patternID, index: index, typeID: newValue)
            }
        )
    }

    private func deleteRows(_ offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            store.removeCycleDay(patternID: patternID, index: index)
        }
    }

    // MARK: - Предпросмотр

    private func previewStrip(pattern: WorkPattern) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<14, id: \.self) { offset in
                    previewCell(offset: offset, pattern: pattern)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func previewCell(offset: Int, pattern: WorkPattern) -> some View {
        let date = Cal.addDays(offset, to: Cal.startOfDay(Date()))
        let type = store.data.patternShiftType(for: date, in: pattern)
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

    private func loadIfNeeded() {
        guard !didLoad, let pattern = pattern else { return }
        name = pattern.name
        anchor = Cal.startOfDay(pattern.anchorDate)
        didLoad = true
    }
}
