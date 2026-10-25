import SwiftUI

struct YearScreen: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var nav: AppNavigation
    @State private var year: Int = Cal.year(Date())

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let dotColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    yearHeader

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(1...12, id: \.self) { monthNumber in
                            monthCard(monthNumber: monthNumber)
                        }
                    }
                }
                .padding(12)
            }
            .background(Color.appGroupedBackground)
            .navigationTitle("Год")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var yearHeader: some View {
        HStack(spacing: 8) {
            Button {
                year -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text(String(year))
                    .font(.headline)
                    .foregroundStyle(Color.appLabel)
                if year != Cal.year(Date()) {
                    Button("Текущий год") {
                        year = Cal.year(Date())
                    }
                    .font(.caption2)
                }
            }
            .frame(height: 38)

            Spacer(minLength: 0)

            Button {
                year += 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
        }
        .buttonStyle(.borderless)
    }

    private func monthCard(monthNumber: Int) -> some View {
        let date = Cal.monthDate(year: year, month: monthNumber)
        let cells = Cal.cells(for: date)
        let stats = store.stats(for: date)
        let isCurrentMonth = Cal.calendar.isDate(date, equalTo: Date(), toGranularity: .month)

        return Button {
            nav.openMonth(date)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(Cal.monthShortTitle(date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCurrentMonth ? Color.accentColor : Color.appLabel)
                    Spacer(minLength: 0)
                    Text("\(stats.workingDays)")
                        .font(.caption2)
                        .foregroundStyle(Color.appSecondaryLabel)
                }

                LazyVGrid(columns: dotColumns, spacing: 3) {
                    ForEach(cells) { cell in
                        dot(for: cell)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appCellBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isCurrentMonth ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private func dot(for cell: CalendarCell) -> some View {
        Group {
            if let date = cell.date {
                let type = store.shiftType(for: date)
                Circle()
                    .fill(type?.isWorking == true ? (type?.color ?? Color.gray) : Color.appFill)
                    .frame(width: 6, height: 6)
            } else {
                Color.clear
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
