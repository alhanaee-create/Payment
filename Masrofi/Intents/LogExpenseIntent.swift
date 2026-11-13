import AppIntents
import CoreLocation
import SwiftData

/// الإجراء اللي يناديه اختصار "المعاملة" كل ما تدفع بـ Apple Pay.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "سجّل مصروف"
    static var description = IntentDescription("يسجّل عملية دفع في مصروفي: المبلغ، المتجر، البطاقة، والمكان.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "المبلغ", description: "اختر: مدخلات الاختصار ← المبلغ")
    var amount: String

    @Parameter(title: "المتجر", description: "اختر: مدخلات الاختصار ← التاجر")
    var merchant: String?

    @Parameter(title: "البطاقة", description: "اختر: مدخلات الاختصار ← البطاقة")
    var card: String?

    @Parameter(title: "الموقع", description: "اختر: الموقع الحالي")
    var location: CLPlacemark?

    static var parameterSummary: some ParameterSummary {
        Summary("سجّل \(\.$amount) في \(\.$merchant)") {
            \.$card
            \.$location
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let parsed = AmountParser.parse(amount) else {
            throw $amount.needsValueError("ما قدرت أقرأ المبلغ. وش المبلغ؟")
        }

        let merchantName = (merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(
            amount: parsed.value,
            currency: parsed.currency,
            merchant: merchantName,
            card: card ?? "",
            date: .now,
            category: Categorizer.guess(merchantName),
            source: "applepay"
        )

        // الموقع: من الاختصار أولاً، وإلا نحاول من التطبيق.
        if let placemark = location, let loc = placemark.location {
            expense.setLocation(loc)
            expense.placeName = LocationService.describe(placemark)
        } else if let loc = await LocationService.shared.currentLocation(timeout: 5) {
            expense.setLocation(loc)
            expense.placeName = await LocationService.placeName(for: loc)
        }

        let context = Store.container.mainContext
        context.insert(expense)
        try context.save()

        await Notifier.notifyLogged(amount: expense.formattedAmount, merchant: expense.displayMerchant)
        return .result(dialog: "تم تسجيل \(expense.formattedAmount) في \(expense.displayMerchant)")
    }
}
