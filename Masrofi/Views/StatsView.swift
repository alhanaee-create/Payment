import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Expense.date) private var all: [Expense]
    @State private var month = Date()

    private let cal = Calendar.current

    private struct CategoryTotal: Identifiable {
        let category: ExpenseCategory
        let total: Double
        var id: String { category.rawValue }
    }

    private struct DayTotal: Identifiable {
        let day: Date
        let total: Double
        var id: Date { day }
    }

    private struct MerchantTotal: Identifiable {
        let name: String
        let total: Double
        let count: Int
        var id: String { name }
    }

    private func items(in date: Date) -> [Expense] {
        all.filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }
    }

    private var monthItems: [Expense] { items(in: month) }
    private var total: Double { monthItems.reduce(0) { $0 + $1.amount } }

    private var previousTotal: Double {
        guard let prev = cal.date(byAdding: .month, value: -1, to: month) else { return 0 }
        return items(in: prev).reduce(0) { $0 + $1.amount }
    }

    private var byCategory: [CategoryTotal] {
        Dictionary(grouping: monthItems, by: \.category)
            .map { CategoryTotal(category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    private var byDay: [DayTotal] {
        Dictionary(grouping: monthItems) { cal.startOfDay(for: $0.date) }
            .map { DayTotal(day: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.day < $1.day }
    }

    private var topMerchants: [MerchantTotal] {
        Dictionary(grouping: monthItems, by: \.displayMerchant)
            .map { MerchantTotal(name: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }, count: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }

    private var isCurrentMonth: Bool { cal.isDate(month, equalTo: .now, toGranularity: .month) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { shift(-1) } label: { Image(systemName: "chevron.backward") }
                        Spacer()
                        Text(month, format: .dateTime.month(.wide).year())
                            .font(.headline)
                        Spacer()
                        Button { shift(1) } label: { Image(systemName: "chevron.forward") }
                            .disabled(isCurrentMonth)
                    }
                    .buttonStyle(.borderless)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(Fmt.money(total))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        if previousTotal > 0 {
                            let diff = (total - previousTotal) / previousTotal * 100
                            Label(
                                "\(abs(diff), format: .number.precision(.fractionLength(0)))٪ \(diff >= 0 ? "أكثر" : "أقل") من الشهر اللي قبله",
                                systemImage: diff >= 0 ? "arrow.up.right" : "arrow.down.right"
                            )
                            .font(.subheadline)
                            .foregroundStyle(diff >= 0 ? .red : .green)
                        }
                        Text("\(monthItems.count) عملية")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if monthItems.isEmpty {
                    ContentUnavailableView("ما فيه صرف هذا الشهر", systemImage: "chart.pie")
                        .listRowBackground(Color.clear)
                } else {
                    Section("حسب التصنيف") {
                        Chart(byCategory) { item in
                            SectorMark(angle: .value("المبلغ", item.total), innerRadius: .ratio(0.6), angularInset: 1.5)
                                .foregroundStyle(item.category.color)
                                .cornerRadius(4)
                        }
                        .frame(height: 220)
                        .padding(.vertical, 8)

                        ForEach(byCategory) { item in
                            HStack {
                                CategoryBadge(category: item.category, size: 32)
                                Text(item.category.title)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text(Fmt.money(item.total)).monospacedDigit()
                                    Text(item.total / max(total, 0.01), format: .percent.precision(.fractionLength(0)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section("الصرف اليومي") {
                        Chart(byDay) { item in
                            BarMark(x: .value("اليوم", item.day, unit: .day), y: .value("المبلغ", item.total))
                                .foregroundStyle(Color.accentColor.gradient)
                                .cornerRadius(3)
                        }
                        .frame(height: 180)
                        .padding(.vertical, 8)
                    }

                    Section("أكثر المتاجر صرفاً") {
                        ForEach(topMerchants) { m in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(m.name).lineLimit(1)
                                    Text("\(m.count) مرة").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Fmt.money(m.total)).monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("الإحصائيات")
        }
    }

    private func shift(_ value: Int) {
        if let d = cal.date(byAdding: .month, value: value, to: month) { month = d }
    }
}
