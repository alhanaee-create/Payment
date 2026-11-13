import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var category: ExpenseCategory = .other
    @State private var categoryTouched = false
    @State private var date = Date()
    @State private var note = ""
    @State private var useLocation = true
    @State private var saving = false
    @FocusState private var amountFocused: Bool

    private var parsed: AmountParser.Result? { AmountParser.parse(amountText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("المبلغ", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .focused($amountFocused)
                    TextField("المتجر", text: $merchant)
                        .onChange(of: merchant) { _, value in
                            if !categoryTouched { category = Categorizer.guess(value) }
                        }
                }
                Section {
                    Picker("التصنيف", selection: Binding(
                        get: { category },
                        set: { category = $0; categoryTouched = true }
                    )) {
                        ForEach(ExpenseCategory.allCases) { c in
                            Label(c.title, systemImage: c.icon).tag(c)
                        }
                    }
                    DatePicker("التاريخ", selection: $date)
                    Toggle("احفظ موقعي الحالي", isOn: $useLocation)
                    TextField("ملاحظة", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("عملية جديدة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("حفظ") { Task { await save() } }
                            .disabled(parsed == nil)
                    }
                }
            }
            .onAppear {
                amountFocused = true
                useLocation = LocationService.shared.isAuthorized
            }
            .onChange(of: useLocation) { _, on in
                if on && !LocationService.shared.isAuthorized {
                    LocationService.shared.requestPermission()
                }
            }
        }
    }

    private func save() async {
        guard let parsed else { return }
        saving = true
        let expense = Expense(
            amount: parsed.value,
            currency: parsed.currency,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            category: category
        )
        expense.note = note
        if useLocation, let loc = await LocationService.shared.currentLocation() {
            expense.setLocation(loc)
            expense.placeName = await LocationService.placeName(for: loc)
        }
        context.insert(expense)
        try? context.save()
        dismiss()
    }
}
