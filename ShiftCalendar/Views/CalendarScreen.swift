import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var nav: AppNavigation
    @State private var selection: DaySelection?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                MonthHeader(month: $nav.month)
                    .padding(.horizontal, 2)

                weekdayRow

                grid

                summaryBar
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
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

    private var grid: some View {
        GeometryReader { proxy in
            let cells = Cal.cells(for: nav.month)
            let rows = max(1, (cells.count + 6) / 7)
            let spacing: CGFloat = 4
            let cellHeight = max(
                50,
                (proxy.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            )

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(cells) { cell in
                    if let date = cell.date {
                        DayCell(
                            date: date,
                            shift: store.shiftType(for: date),
                            hours: store.hours(for: date),
                            showHours: cellHeight >= 84,
                            hasNote: !store.note(for: date).isEmpty,
                            isOverridden: store.hasOverride(date) || store.hasHoursOverride(date),
                            isToday: Cal.isToday(date),
                            isWeekend: cell.isWeekend,
                            height: cellHeight
                        ) {
                            selection = DaySelection(date: date)
                        }
                    } else {
                        Color.clear
                            .frame(height: cellHeight)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > abs(dy), abs(dx) > 40 else { return }
                        changeMonth(dx < 0 ? 1 : -1)
                    }
            )
        }
        .frame(maxHeight: .infinity)
    }

    private var summaryBar: some View {
        let stats = store.stats(for: nav.month)
        return HStack(spacing: 8) {
            Text("\(stats.workingDays) смен")
            Text("·")
            Text(stats.hoursText)
            Text("·")
            Text(Fmt.money(stats.totalPay, currency: store.data.settings.currency))
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(Color.appSecondaryLabel)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func changeMonth(_ delta: Int) {
        withAnimation(.easeInOut(duration: 0.18)) {
            nav.month = Cal.addMonths(delta, to: nav.month)
        }
    }
}
