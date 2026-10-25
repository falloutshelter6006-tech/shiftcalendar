import Foundation

/// Форматирование чисел, часов и денег в русской локали.
enum Fmt {
    private static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = " "
        return f
    }()

    private static func number(_ value: Double, fractionDigits: Int) -> String {
        decimal.minimumFractionDigits = 0
        decimal.maximumFractionDigits = fractionDigits
        return decimal.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    /// 7,5 → "7,5 ч"
    static func hours(_ value: Double) -> String {
        guard value > 0 else { return "0 ч" }
        return number(value, fractionDigits: 1) + " ч"
    }

    /// 65 400 → "65 400 ₽"
    static func money(_ value: Double, currency: String) -> String {
        guard value != 0 else { return "0 " + currency }
        return number(value, fractionDigits: value >= 100 ? 0 : 2) + " " + currency
    }

    static func rate(_ value: Double, currency: String) -> String {
        number(value, fractionDigits: 2) + " " + currency
    }
}
