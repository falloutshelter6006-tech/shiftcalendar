import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var month: Date = Cal.startOfMonth(Date())
    @State private var selection: DaySelection?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                MonthHeader(month: $month)
                    .padding(.horizontal, 4)

                weekdayRow

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(Cal.cells(for: month)) { cell in
                            if let date = cell.date {
                                DayCell(
                                    date: date,
                                    shift: store.shiftType(for: date),
                                    hasNote: !store.note(for: date).isEmpty,
                                    isOverridden: store.hasOverride(date),
                                    isToday: Cal.isToday(date),
                                    isWeekend: cell.isWeekend
                                ) {
                                    selection = DaySelection(date: date)
                                }
                            } else {
                                Color.clear
                                    .frame(height: DayCell.height)
                            }
                        }
                    }
                    .padding(.bottom, 6)

                    summary
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .background(Color.appGroupedBackground)
            .navigationTitle("Смены")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selection) { item in
                DayDetailView(date: item.date)
                    .environmentObject(store)
            }
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(Cal.weekdayShort, id: \.self) { title in
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.appSecondaryLabel)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var summary: some View {
        let stats = store.stats(for: month)
        return HStack(spacing: 14) {
            summaryItem(icon: "briefcase", text: "\(stats.workingDays) смен")
            summaryItem(icon: "clock", text: stats.hoursText)
            summaryItem(icon: "moon.zzz", text: "\(stats.offDays) вых.")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private func summaryItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(Color.appSecondaryLabel)
    }
}
