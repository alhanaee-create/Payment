import SwiftUI
import SwiftData

struct ExpensesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var showingAdd = false
    @State private var search = ""

    private struct DayGroup: Identifiable {
        let day: Date
        let items: [Expense]
        var id: Date { day }
        var total: Double { items.reduce(0) { $0 + $1.amount } }
    }

    private var filtered: [Expense] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return expenses }
        return expenses.filter {
            $0.merchant.localizedCaseInsensitiveContains(q)
            || $0.note.localizedCaseInsensitiveContains(q)
            || $0.placeName.localizedCaseInsensitiveContains(q)
            || $0.category.title.localizedCaseInsensitiveContains(q)
        }
    }

    private var groups: [DayGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { DayGroup(day: $0, items: dict[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SummaryCard(expenses: expenses)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if expenses.isEmpty {
                    ContentUnavailableView(
                        "ما فيه عمليات للحين",
                        systemImage: "creditcard",
                        description: Text("اضبط الأتمتة من تبويب «الإعداد»، وبعدها كل ما تدفع بـ Apple Pay تنسجل العملية هنا تلقائياً.")
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(groups) { group in
                    Section {
                        ForEach(group.items) { expense in
                            NavigationLink(value: expense) {
                                ExpenseRow(expense: expense)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(group.items[i]) }
                            try? context.save()
                        }
                    } header: {
                        HStack {
                            Text(group.day, format: .dateTime.weekday(.wide).day().month(.wide))
                            Spacer()
                            Text(Fmt.money(group.total))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("مصروفي")
            .navigationDestination(for: Expense.self) { ExpenseDetailView(expense: $0) }
            .searchable(text: $search, prompt: "ابحث عن متجر أو ملاحظة")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .accessibilityLabel("إضافة عملية")
                }
            }
            .sheet(isPresented: $showingAdd) { AddExpenseView() }
        }
    }
}

struct SummaryCard: View {
    let expenses: [Expense]

    private var today: Double {
        expenses.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }

    private var monthItems: [Expense] {
        expenses.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    private var month: Double { monthItems.reduce(0) { $0 + $1.amount } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("صرفك هذا الشهر")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(Fmt.money(month))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack {
                stat("اليوم", Fmt.money(today))
                Spacer()
                stat("عدد العمليات", "\(monthItems.count)")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .padding(.vertical, 6)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.8))
            Text(value).font(.headline).monospacedDigit().foregroundStyle(.white)
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: expense.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.displayMerchant)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(expense.date, format: .dateTime.hour().minute())
                    if !expense.placeName.isEmpty {
                        Text("•")
                        Image(systemName: "mappin").imageScale(.small)
                        Text(expense.placeName).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.formattedAmount)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    if expense.receiptImage != nil {
                        Image(systemName: "doc.text.image")
                    }
                    if expense.isApplePay {
                        Image(systemName: "apple.logo")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.15), in: Circle())
    }
}
