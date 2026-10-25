import SwiftUI

struct StatsScreen: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var nav: AppNavigation

    private let cardColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var stats: MonthStats {
        store.stats(for: nav.month)
    }

    private var currency: String {
        store.data.settings.currency
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MonthHeader(month: $nav.month)
                        .padding(.horizontal, 2)

                    LazyVGrid(columns: cardColumns, spacing: 10) {
                        statCard(
                            title: "Смен",
                            value: "\(stats.workingDays)",
                            detail: "\(stats.offDays) вых.",
                            tint: .blue
                        )
                        statCard(
                            title: "Часов",
                            value: stats.hoursText,
                            detail: stats.nightHours > 0
                                ? "ночных \(Fmt.hours(stats.nightHours))"
                                : "за месяц",
                            tint: .green
                        )
                        statCard(
                            title: "Начислено",
                            value: Fmt.money(stats.totalPay, currency: currency),
                            detail: "за месяц",
                            tint: .orange
                        )
                        statCard(
                            title: "Переработка",
                            value: Fmt.hours(stats.overtimeHours),
                            detail: "сверх смены",
                            tint: .purple
                        )
                    }

                    breakdown
                    ratesCard
                }
                .padding(16)
            }
            .background(Color.appGroupedBackground)
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Карточки

    private func statCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appLabel)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(Color.appSecondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appCellBackground)
        )
    }

    // MARK: - Разбивка по типам

    private var breakdown: some View {
        let totalDays = max(stats.counts.reduce(0) { $0 + $1.days }, 1)

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
                        VStack(spacing: 5) {
                            HStack(spacing: 6) {
                                ColorDot(color: item.type.color, size: 9)
                                Text(item.type.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appLabel)
                                Spacer(minLength: 4)
                                if item.type.isWorking {
                                    Text(Fmt.money(item.pay, currency: currency))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.appLabel)
                                }
                            }

                            HStack(spacing: 6) {
                                Text("\(item.days) дн.")
                                if item.type.isWorking {
                                    Text("· \(Fmt.hours(item.hours))")
                                }
                                Spacer(minLength: 4)
                                Text(item.type.timeRangeText)
                            }
                            .font(.caption2)
                            .foregroundStyle(Color.appSecondaryLabel)

                            ProgressView(
                                value: Double(item.days),
                                total: Double(totalDays)
                            )
                            .tint(item.type.color)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Тарифы

    private var ratesCard: some View {
        let working = store.data.shiftTypes.filter { $0.isWorking }
        let hasRates = working.contains { type in
            type.payRule.mode == .hourly
                ? type.payRule.hourlyRate > 0
                : type.payRule.shiftRate > 0
        }
        let settings = store.data.settings

        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Тарифы")
                    .font(.headline)
                    .foregroundStyle(Color.appLabel)

                if working.isEmpty {
                    Text("Нет рабочих типов смен")
                        .font(.subheadline)
                        .foregroundStyle(Color.appSecondaryLabel)
                } else {
                    ForEach(working) { type in
                        HStack(spacing: 6) {
                            ColorDot(color: type.color, size: 8)
                            Text(type.name)
                                .font(.subheadline)
                                .foregroundStyle(Color.appLabel)
                            Spacer(minLength: 4)
                            Text(rateText(type))
                                .font(.caption)
                                .foregroundStyle(Color.appSecondaryLabel)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Divider()

                Text(detailLine(settings: settings))
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondaryLabel)

                if !hasRates {
                    Text("Ставки не заданы: Настройки → Типы смен → выбери тип.")
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                }
            }
        }
    }

    private func rateText(_ type: ShiftType) -> String {
        let rule = type.payRule
        var text: String
        switch rule.mode {
        case .hourly:
            text = rule.hourlyRate > 0
                ? "\(Fmt.rate(rule.hourlyRate, currency: currency))/ч"
                : "ставка не задана"
        case .perShift:
            text = rule.shiftRate > 0
                ? "\(Fmt.rate(rule.shiftRate, currency: currency))/смена"
                : "ставка не задана"
        }
        if rule.mode == .hourly, rule.nightBonusPercent > 0 {
            text += " · ночь +\(Int(rule.nightBonusPercent))%"
        }
        return text
    }

    private func detailLine(settings: AppSettings) -> String {
        let multiplier = String(format: "%.1f", settings.overtimeMultiplier)
            .replacingOccurrences(of: ".", with: ",")
        let window = "\(Cal.timeText(settings.nightStartMinutes))–\(Cal.timeText(settings.nightEndMinutes))"
        return "Переработка ×\(multiplier) · ночные с \(window)"
    }
}
