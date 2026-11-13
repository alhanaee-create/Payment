import SwiftUI

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case food, coffee, groceries, fuel, shopping, transport, bills, health, entertainment, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "مطاعم"
        case .coffee: "قهوة"
        case .groceries: "بقالة"
        case .fuel: "بنزين"
        case .shopping: "تسوّق"
        case .transport: "مواصلات"
        case .bills: "فواتير"
        case .health: "صحة"
        case .entertainment: "ترفيه"
        case .other: "أخرى"
        }
    }

    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .coffee: "cup.and.saucer.fill"
        case .groceries: "cart.fill"
        case .fuel: "fuelpump.fill"
        case .shopping: "bag.fill"
        case .transport: "car.fill"
        case .bills: "doc.text.fill"
        case .health: "cross.case.fill"
        case .entertainment: "film.fill"
        case .other: "creditcard.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: .orange
        case .coffee: .brown
        case .groceries: .green
        case .fuel: .red
        case .shopping: .pink
        case .transport: .blue
        case .bills: .indigo
        case .health: .teal
        case .entertainment: .purple
        case .other: .gray
        }
    }
}
