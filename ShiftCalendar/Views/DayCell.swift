import SwiftUI

struct DayCell: View {
    let date: Date
    let shift: ShiftType?
    let hours: Double
    let showHours: Bool
    let hasNote: Bool
    let isOverridden: Bool
    let isToday: Bool
    let isWeekend: Bool
    let height: CGFloat
    let action: () -> Void

    private var dayFont: CGFloat {
        min(max(13, height * 0.24), 22)
    }

    private var chipFont: CGFloat {
        min(max(9, height * 0.15), 13)
    }

    private var circleSize: CGFloat {
        min(max(20, height * 0.32), 32)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(Cal.dayNumber(date))")
                    .font(.system(size: dayFont, weight: isToday ? .bold : .medium))
                    .foregroundStyle(dayNumberColor)
                    .frame(width: circleSize, height: circleSize)
                    .background(
                        Circle()
                            .fill(isToday ? Color.accentColor : Color.clear)
                    )

                if let shift = shift {
                    Text(shift.chipText)
                        .font(.system(size: chipFont, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(shift.isWorking ? Color.white : Color.appSecondaryLabel)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(shift.isWorking ? shift.color : Color.appFill)
                        )
                }

                if showHours, let shift = shift, shift.isWorking {
                    Text(Fmt.hours(hours))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.appSecondaryLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appCellBackground)
            )
            .overlay(alignment: .topTrailing) {
                if hasNote || isOverridden {
                    Circle()
                        .fill(hasNote ? Color.orange : Color.accentColor)
                        .frame(width: 5, height: 5)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var dayNumberColor: Color {
        if isToday { return .white }
        if isWeekend { return Color.red.opacity(0.85) }
        return Color.appLabel
    }
}
