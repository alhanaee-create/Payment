import Foundation
import SwiftData
import CoreLocation

/// عملية دفع واحدة.
@Model
final class Expense {
    var amount: Double = 0
    /// رمز العملة (مثل SAR). فارغ = عملة الجهاز.
    var currency: String = ""
    var merchant: String = ""
    var card: String = ""
    var date: Date = Date()
    var latitude: Double?
    var longitude: Double?
    var placeName: String = ""
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var note: String = ""
    /// "applepay" لو انسجلت تلقائياً من الاختصار، و "manual" لو أضفتها بنفسك.
    var source: String = "manual"
    @Attribute(.externalStorage) var receiptImage: Data?

    init(amount: Double,
         currency: String = "",
         merchant: String,
         card: String = "",
         date: Date = .now,
         category: ExpenseCategory = .other,
         source: String = "manual") {
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.card = card
        self.date = date
        self.categoryRaw = category.rawValue
        self.source = source
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isApplePay: Bool { source == "applepay" }

    var displayMerchant: String {
        merchant.trimmingCharacters(in: .whitespaces).isEmpty ? "بدون اسم" : merchant
    }

    var formattedAmount: String { Fmt.money(amount, currency: currency) }

    func setLocation(_ location: CLLocation?) {
        guard let location else { return }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
    }
}
