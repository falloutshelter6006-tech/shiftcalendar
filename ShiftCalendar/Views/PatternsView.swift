import SwiftUI

struct PatternsView: View {
    @EnvironmentObject private var store: ScheduleStore

    private var canDelete: Bool {
        store.data.patterns.count > 1
    }

    var body: some View {
        List {
            Section {
                ForEach(store.data.patterns) { pattern in
                    HStack(spacing: 10) {
                        Button {
                            store.setActivePattern(pattern.id)
                        } label: {
                            Image(systemName: isActive(pattern)
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isActive(pattern)
                                                 ? Color.accentColor
                                                 : Color.appSecondaryLabel)
                        }
                        .buttonStyle(.borderless)

                        NavigationLink {
                            PatternEditorView(patternID: pattern.id)
                        } label: {
                            row(for: pattern)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if canDelete {
                            Button(role: .destructive) {
                                store.deletePattern(pattern.id)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Графики")
            } footer: {
                Text("Галочка отмечает активный график — по нему считается календарь. Ручные правки дней сохраняются при переключении.")
            }

            Section {
                Button {
                    _ = store.addPattern()
                } label: {
                    Label("Добавить график", systemImage: "plus.circle")
                }
            } footer: {
                Text("Новый график создаётся как копия активного. Дальше можно поменять цикл и дату-якорь.")
            }
        }
        .navigationTitle("Мои графики")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isActive(_ pattern: WorkPattern) -> Bool {
        pattern.id == store.data.activePatternID
    }

    private func row(for pattern: WorkPattern) -> some View {
        let working = pattern.cycle.filter { id in
            store.data.shiftType(id: id)?.isWorking == true
        }.count
        let off = pattern.cycle.count - working

        return VStack(alignment: .leading, spacing: 3) {
            Text(pattern.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appLabel)

            HStack(spacing: 4) {
                Text("\(working) раб. / \(off) вых.")
                Text("·")
                Text("\(pattern.cycle.count) дн. в цикле")
                Text("·")
                Text("с \(Cal.shortDayTitle(pattern.anchorDate))")
            }
            .font(.caption2)
            .foregroundStyle(Color.appSecondaryLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 2)
    }
}
