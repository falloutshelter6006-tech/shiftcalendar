import SwiftUI

struct DayCell: View {
    static let height: CGFloat = 66

    let date: Date
    let shift: ShiftType?
    let hasNote: Bool
    let isOverridden: Bool
    let isToday: Bool
    let isWeekend: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(Cal.dayNumber(date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(dayNumberColor)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(isToday ? Color.accentColor : Color.clear)
                    )

                chip

                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .frame(height: DayCell.height)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appCellBackground)
            )
            .overlay(alignment: .topTrailing) {
                if hasNote || isOverridden {
                    Circle()
                        .fill(hasNote ? Color.orange : Color.accentColor)
                        .frame(width: 5, height: 5)
                        .padding(5)
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

    @ViewBuilder
    private var chip: some View {
        if let shift = shift {
            Text(shift.chipText)
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(shift.isWorking ? Color.white : Color.appSecondaryLabel)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(shift.isWorking ? shift.color : Color.appFill)
                )
        } else {
            Color.clear.frame(height: 14)
        }
    }
}
