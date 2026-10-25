import SwiftUI

/// Месяц на A4 для печати/PDF. Явные цвета — чтобы тёмная тема не влияла.
struct MonthPDFView: View {
    let data: ScheduleData
    let month: Date

    private let cellWidth: CGFloat = 74
    private let cellHeight: CGFloat = 58
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            grid
            legend
            Spacer(minLength: 0)
            summary
        }
        .padding(28)
        .foregroundStyle(Color.black)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("График смен · \(Cal.monthTitle(month))")
                .font(.system(size: 22, weight: .bold))
            Text(patternLabel)
                .font(.system(size: 11))
                .foregroundStyle(Color.black.opacity(0.6))
        }
    }

    private var patternLabel: String {
        let name = data.activePattern?.name ?? "График"
        return "Цикл: \(name) · \(data.activePattern?.cycle.count ?? 0) дн."
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Cal.weekdayShort, id: \.self) { title in
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .frame(width: cellWidth, height: 18)
            }

            ForEach(Cal.cells(for: month)) { cell in
                dayCell(cell)
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.black.opacity(0.25), lineWidth: 0.8)
        )
    }

    private func dayCell(_ cell: CalendarCell) -> some View {
        Group {
            if let date = cell.date {
                let type = data.shiftType(for: date)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Text("\(Cal.dayNumber(date))")
                            .font(.system(size: 10, weight: .semibold))
                        Spacer(minLength: 0)
                        if cell.isWeekend {
                            Text("вс")
                                .font(.system(size: 6))
                                .foregroundStyle(Color.black.opacity(0.35))
                        }
                    }

                    Spacer(minLength: 0)

                    if let type = type {
                        Text(type.chipText)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(type.isWorking ? Color.white : Color.black.opacity(0.55))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(type.isWorking ? type.color : Color.black.opacity(0.08))
                            )

                        if type.isWorking {
                            Text(Fmt.hours(data.hours(for: date)))
                                .font(.system(size: 7))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }
                    }
                }
                .padding(3)
                .frame(width: cellWidth, height: cellHeight, alignment: .topLeading)
                .background(backgroundColor(for: date))
            } else {
                Color.clear
                    .frame(width: cellWidth, height: cellHeight)
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func backgroundColor(for date: Date) -> Color {
        if Cal.isToday(date) {
            return Color.black.opacity(0.06)
        }
        return Color.white
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(data.shiftTypes) { type in
                HStack(spacing: 4) {
                    Circle()
                        .fill(type.isWorking ? type.color : Color.black.opacity(0.15))
                        .frame(width: 7, height: 7)
                    Text("\(type.name) · \(type.timeRangeText)")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.black.opacity(0.65))
                }
            }
        }
    }

    private var summary: some View {
        let stats = data.stats(in: month)
        return HStack(spacing: 18) {
            summaryItem(title: "Смен", value: "\(stats.workingDays)")
            summaryItem(title: "Выходных", value: "\(stats.offDays)")
            summaryItem(title: "Часов", value: Fmt.hours(stats.totalHours))
            summaryItem(
                title: "Начислено",
                value: Fmt.money(stats.totalPay, currency: data.settings.currency)
            )
        }
        .padding(.top, 6)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.15))
                .frame(height: 0.8)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(Color.black.opacity(0.55))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
    }
}
