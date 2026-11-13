import Foundation

/// يقرأ المبلغ من النص اللي يرسله الاختصار، مثل:
/// "SAR 25.00" أو "٢٥٫٥٠ ر.س." أو "$1,234.50" أو "1.250 KWD".
enum AmountParser {
    struct Result: Equatable {
        var value: Double
        var currency: String
    }

    private static let symbolToCode: [String: String] = [
        "ر.س": "SAR", "﷼": "SAR", "رس": "SAR",
        "د.إ": "AED", "درهم": "AED",
        "د.ك": "KWD", "دك": "KWD",
        "ر.ق": "QAR", "رق": "QAR",
        "د.ب": "BHD", "دب": "BHD",
        "ر.ع": "OMR", "رع": "OMR",
        "$": "USD", "US$": "USD", "€": "EUR", "£": "GBP",
    ]

    static func parse(_ raw: String) -> Result? {
        // 1) حوّل الأرقام العربية إلى إنجليزية.
        var s = ""
        for ch in raw {
            // تجاهل علامات الاتجاه المخفية (RLM/LRM).
            if ch.unicodeScalars.allSatisfy({ $0.properties.generalCategory == .format }) { continue }
            if ch.isNumber, let v = ch.wholeNumberValue {
                s.append(String(v))
            } else if ch == "٫" {
                s.append(".")
            } else if ch == "٬" {
                s.append(",")
            } else if ch == "−" {
                s.append("-")
            } else {
                s.append(ch)
            }
        }

        // 2) استخرج الرقم.
        guard let match = s.firstMatch(of: #/[0-9][0-9.,]*/#) else { return nil }
        var number = String(match.output)
        while let last = number.last, last == "." || last == "," { number.removeLast() }

        let hasDot = number.contains(".")
        let hasComma = number.contains(",")
        if hasDot && hasComma {
            // الفاصل الأخير هو الكسور.
            let lastDot = number.lastIndex(of: ".")!
            let lastComma = number.lastIndex(of: ",")!
            if lastDot > lastComma {
                number.removeAll { $0 == "," }
            } else {
                number.removeAll { $0 == "." }
                number = number.replacingOccurrences(of: ",", with: ".")
            }
        } else if hasComma {
            let parts = number.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2, let decimals = parts.last, (1...2).contains(decimals.count) {
                number = number.replacingOccurrences(of: ",", with: ".")
            } else {
                number.removeAll { $0 == "," }
            }
        } else if hasDot {
            if number.filter({ $0 == "." }).count > 1 {
                number.removeAll { $0 == "." }
            }
        }

        guard var value = Double(number) else { return nil }
        let before = s[s.startIndex..<match.range.lowerBound]
        if before.contains("-") { value = -value }

        // 3) العملة = النص الباقي.
        var rest = s
        rest.removeSubrange(match.range)
        let currencyText = rest
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters).subtracting(CharacterSet(charactersIn: "$€£")))
        return Result(value: value, currency: currencyCode(from: currencyText))
    }

    static func currencyCode(from text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "" }
        let upper = t.uppercased()
        if let code = upper.firstMatch(of: #/[A-Z]{3}/#), upper.count <= 5 {
            return String(code.output)
        }
        if let code = symbolToCode[t] { return code }
        let compact = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "")
        for (symbol, code) in symbolToCode where symbol.replacingOccurrences(of: ".", with: "") == compact {
            return code
        }
        return t
    }
}
