import Foundation

enum Fmt {
    /// عملة الجهاز الافتراضية.
    static var defaultCurrency: String { Locale.current.currency?.identifier ?? "SAR" }

    static func money(_ value: Double, currency: String = "") -> String {
        let code = currency.isEmpty ? defaultCurrency : currency
        if code.count == 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) {
            return value.formatted(.currency(code: code.uppercased()).precision(.fractionLength(0...2)))
        }
        return value.formatted(.number.precision(.fractionLength(0...2))) + " " + code
    }
}
