import SwiftData

/// قاعدة البيانات المشتركة بين التطبيق والاختصار (App Intent).
@MainActor
enum Store {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Expense.self)
        } catch {
            fatalError("تعذّر فتح قاعدة البيانات: \(error)")
        }
    }()
}
