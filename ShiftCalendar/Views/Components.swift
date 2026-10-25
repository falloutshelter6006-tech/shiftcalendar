import SwiftUI

/// Выбранный в календаре день для показа деталей.
struct DaySelection: Identifiable {
    let date: Date
    var id: String { Cal.dayKey(date) }
}

struct ColorDot: View {
    let color: Color
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

struct MonthHeader: View {
    @Binding var month: Date

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    month = Cal.addMonths(-1, to: month)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text(Cal.monthTitle(month))
                    .font(.headline)
                    .foregroundStyle(Color.appLabel)

                if !Cal.calendar.isDate(month, equalTo: Date(), toGranularity: .month) {
                    Button("Текущий месяц") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            month = Cal.startOfMonth(Date())
                        }
                    }
                    .font(.caption2)
                }
            }
            .frame(height: 38)

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    month = Cal.addMonths(1, to: month)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
        }
        .buttonStyle(.borderless)
    }
}

/// Заголовок блока с содержимым на «карточке».
struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appCellBackground)
            )
    }
}
