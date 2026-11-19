import SwiftUI
import SwiftData
import Charts

struct ExpensesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var showingAdd = false
    @State private var search = ""
    @State private var filter: ExpenseCategory?

    private struct DayGroup: Identifiable {
        let day: Date
        let items: [Expense]
        var id: Date { day }
        var total: Double { items.reduce(0) { $0 + $1.amount } }
    }

    /// التصنيفات المستخدمة، الأكثر استخداماً أول.
    private var usedCategories: [ExpenseCategory] {
        Dictionary(grouping: expenses, by: \.category)
            .sorted { $0.value.count > $1.value.count }
            .map(\.key)
    }

    private var filtered: [Expense] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return expenses.filter { e in
            if let filter, e.category != filter { return false }
            guard !q.isEmpty else { return true }
            return e.merchant.localizedCaseInsensitiveContains(q)
                || e.note.localizedCaseInsensitiveContains(q)
                || e.placeName.localizedCaseInsensitiveContains(q)
                || e.category.title.localizedCaseInsensitiveContains(q)
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
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                if usedCategories.count > 1 {
                    Section {
                        filterBar
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    .listSectionSpacing(.compact)
                }

                if expenses.isEmpty {
                    ContentUnavailableView(
                        "ما فيه عمليات للحين",
                        systemImage: "creditcard",
                        description: Text("اضبط الأتمتة من تبويب «الإعداد»، وبعدها كل ما تدفع بـ Apple Pay تنسجل العملية هنا تلقائياً.")
                    )
                    .listRowBackground(Color.clear)
                } else if groups.isEmpty {
                    ContentUnavailableView(
                        "ما فيه نتائج",
                        systemImage: "magnifyingglass",
                        description: Text("جرّب كلمة ثانية أو شيل الفلتر.")
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
                            Text(DayTitle.text(for: group.day))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(Fmt.money(group.total))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                        }
                        .textCase(nil)
                    }
                }
            }
            .navigationTitle("مصروفي")
            .navigationDestination(for: Expense.self) { ExpenseDetailView(expense: $0) }
            .searchable(text: $search, prompt: "ابحث عن متجر أو ملاحظة")
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                FloatingAddButton { showingAdd = true }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .sheet(isPresented: $showingAdd) { AddExpenseView() }
            .animation(.snappy, value: filter)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { filter = nil } label: {
                    CategoryChip(title: "الكل", icon: "square.grid.2x2.fill",
                                 color: .accentColor, selected: filter == nil)
                }
                ForEach(usedCategories) { c in
                    Button { filter = (filter == c ? nil : c) } label: {
                        CategoryChip(title: c.title, icon: c.icon, color: c.color, selected: filter == c)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .sensoryFeedback(.selection, trigger: filter)
    }
}

// MARK: - البطاقة الرئيسية

struct SummaryCard: View {
    let expenses: [Expense]
    @AppStorage(Budget.key) private var budget: Double = 0

    private let cal = Calendar.current

    private struct DayValue: Identifiable {
        let day: Date
        let total: Double
        var id: Date { day }
    }

    private func sum(_ items: [Expense]) -> Double { items.reduce(0) { $0 + $1.amount } }

    private var monthItems: [Expense] {
        expenses.filter { cal.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    private var month: Double { sum(monthItems) }
    private var today: Double { sum(expenses.filter { cal.isDateInToday($0.date) }) }

    /// صرف الشهر اللي قبله لنفس اليوم (مقارنة عادلة).
    private var lastMonthSoFar: Double {
        guard let sameDayLastMonth = cal.date(byAdding: .month, value: -1, to: .now),
              let start = cal.dateInterval(of: .month, for: sameDayLastMonth)?.start
        else { return 0 }
        return sum(expenses.filter { $0.date >= start && $0.date <= sameDayLastMonth })
    }

    private var daysLeftInMonth: Int {
        guard let range = cal.range(of: .day, in: .month, for: .now) else { return 1 }
        return max(range.count - cal.component(.day, from: .now) + 1, 1)
    }

    private var dailyAverage: Double {
        month / Double(max(cal.component(.day, from: .now), 1))
    }

    private var lastSevenDays: [DayValue] {
        let todayStart = cal.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            return DayValue(day: day, total: sum(expenses.filter { cal.isDate($0.date, inSameDayAs: day) }))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("صرفك في \(Date.now.formatted(.dateTime.month(.wide)))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(Fmt.money(month))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                    comparison
                }
                Spacer(minLength: 12)
                if budget > 0 {
                    BudgetRing(progress: month / budget)
                        .frame(width: 64, height: 64)
                }
            }

            if budget > 0 { budgetLine }

            Chart(lastSevenDays) { item in
                BarMark(x: .value("اليوم", item.day, unit: .day),
                        y: .value("المبلغ", item.total))
                    .foregroundStyle(.white.opacity(cal.isDateInToday(item.day) ? 1 : 0.45))
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 70)
            .accessibilityLabel("صرف آخر ٧ أيام")

            Divider().overlay(.white.opacity(0.25))

            HStack {
                stat("اليوم", Fmt.money(today))
                Spacer()
                stat("المعدّل اليومي", Fmt.money(dailyAverage))
                Spacer()
                stat("العمليات", "\(monthItems.count)")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HeroBackground())
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var comparison: some View {
        if lastMonthSoFar > 0 {
            let diff = (month - lastMonthSoFar) / lastMonthSoFar
            HStack(spacing: 4) {
                Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(abs(diff), format: .percent.precision(.fractionLength(0))) \(diff >= 0 ? "أكثر" : "أقل") من الشهر الماضي")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.18), in: Capsule())
        }
    }

    @ViewBuilder
    private var budgetLine: some View {
        let remaining = budget - month
        HStack(spacing: 6) {
            Image(systemName: remaining >= 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            if remaining >= 0 {
                Text("باقي لك \(Fmt.money(remaining)) — تقريباً \(Fmt.money(remaining / Double(daysLeftInMonth))) باليوم")
            } else {
                Text("تجاوزت الميزانية بـ \(Fmt.money(-remaining))")
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.white.opacity(0.92))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - سطر العملية

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
                    Text("•")
                    if expense.placeName.isEmpty {
                        Text(expense.category.title)
                    } else {
                        Image(systemName: "mappin").imageScale(.small)
                        Text(expense.placeName).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.formattedAmount)
                    .font(.body.weight(.bold))
                    .fontDesign(.rounded)
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
        .padding(.vertical, 4)
    }
}

struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}
