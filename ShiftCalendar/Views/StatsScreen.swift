import SwiftUI

struct StatsScreen: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var month: Date = Cal.startOfMonth(Date())

    private var stats: MonthStats {
        store.stats(for: month)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MonthHeader(month: $month)
                        .padding(.horizontal, 2)

                    HStack(spacing: 10) {
                        statCard(title: "Смены", value: "\(stats.workingDays)", tint: .blue)
                        statCard(title: "Часы", value: stats.hoursText, tint: .green)
                        statCard(title: "Выходные", value: "\(stats.offDays)", tint: .orange)
                    }

                    breakdown
                }
                .padding(16)
            }
            .background(Color.appGroupedBackground)
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.appSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appCellBackground)
        )
    }

    private var breakdown: some View {
        let total = stats.counts.reduce(0) { $0 + $1.days }

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("По типам смен")
                    .font(.headline)
                    .foregroundStyle(Color.appLabel)

                if stats.counts.isEmpty {
                    Text("Нет данных за этот месяц")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryLabel)
                } else {
                    ForEach(stats.counts) { item in
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                ColorDot(color: item.type.color, size: 9)
                                Text(item.type.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appLabel)
                                Spacer(minLength: 4)
                                Text(detailText(for: item))
                                    .font(.caption)
                                    .foregroundStyle(Color.appSecondaryLabel)
                            }

                            ProgressView(
                                value: Double(item.days),
                                total: Double(max(total, 1))
                            )
                            .tint(item.type.color)
                        }
                    }
                }
            }
        }
    }

    private func detailText(for item: TypeCount) -> String {
        if item.type.isWorking {
            return "\(item.days) дн · \(String(format: "%.0f", item.hours)) ч"
        }
        return "\(item.days) дн"
    }
}
