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
    @State private var saved = false
    @FocusState private var amountFocused: Bool

    private var parsed: AmountParser.Result? { AmountParser.parse(amountText) }
    private var amountInvalid: Bool {
        !amountText.trimmingCharacters(in: .whitespaces).isEmpty && parsed == nil
    }

    private var currencyLabel: String {
        guard let code = parsed?.currency, !code.isEmpty else { return Fmt.defaultCurrency }
        return code
    }

    private let columns =Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 6) {
                        TextField("٠", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(category.color)
                            .focused($amountFocused)
                        Text(amountInvalid ? "اكتب مبلغ صحيح" : currencyLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(amountInvalid ? .red : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("اسم المتجر", text: $merchant)
                        .font(.body.weight(.medium))
                        .onChange(of: merchant) { _, value in
                            if !categoryTouched { category = Categorizer.guess(value) }
                        }
                }

                Section("التصنيف") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(ExpenseCategory.allCases) { c in
                            categoryButton(c)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    DatePicker("التاريخ", selection: $date)
                    Toggle(isOn: $useLocation) {
                        Label("احفظ موقعي الحالي", systemImage: "location.fill")
                    }
                    TextField("ملاحظة (اختياري)", text: $note, axis: .vertical)
                        .lineLimit(1...4)
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
                            .fontWeight(.bold)
                            .disabled(parsed == nil)
                    }
                }
            }
            .animation(.snappy, value: category)
            .sensoryFeedback(.selection, trigger: category)
            .sensoryFeedback(.success, trigger: saved)
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

    private func categoryButton(_ c: ExpenseCategory) -> some View {
        let selected = c == category
        return Button {
            category = c
            categoryTouched = true
        } label: {
            VStack(spacing: 5) {
                Image(systemName: c.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? .white : c.color)
                    .frame(width: 46, height: 46)
                    .background(selected ? c.color : c.color.opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .scaleEffect(selected ? 1.08 : 1)
                Text(c.title)
                    .font(.caption2.weight(selected ? .bold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
        saved = true
        dismiss()
    }
}
