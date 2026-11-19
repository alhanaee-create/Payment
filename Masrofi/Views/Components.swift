import SwiftUI

/// الميزانية الشهرية (0 = بدون ميزانية).
enum Budget {
    static let key = "monthlyBudget"
}

enum DayTitle {
    /// «اليوم» / «أمس» / «الثلاثاء ١٨ نوفمبر».
    static func text(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "اليوم" }
        if cal.isDateInYesterday(day) { return "أمس" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

/// خلفية البطاقة الرئيسية: لون التطبيق مع تدرّج ودوائر خفيفة.
struct HeroBackground: View {
    var body: some View {
        ZStack {
            Color.accentColor
            LinearGradient(colors: [.white.opacity(0.12), .black.opacity(0.28)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: geo.size.width * 0.8)
                    .offset(x: geo.size.width * 0.45, y: -geo.size.height * 0.45)
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: -geo.size.width * 0.15, y: geo.size.height * 0.55)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.35), radius: 14, y: 8)
    }
}

/// حلقة تقدّم الميزانية.
struct BudgetRing: View {
    let progress: Double
    var lineWidth: CGFloat = 7

    private var tint: Color {
        switch progress {
        case ..<0.75: .white
        case ..<1: .yellow
        default: Color(red: 1, green: 0.45, blue: 0.45)
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: progress)
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .padding(lineWidth)
        }
    }
}

/// زر تصنيف صغير (للفلترة).
struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let selected: Bool

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? .white : color)
            .background(selected ? color : color.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
    }
}

/// زر الإضافة العائم.
struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.accentColor.gradient, in: Circle())
                .shadow(color: Color.accentColor.opacity(0.45), radius: 10, y: 5)
        }
        .accessibilityLabel("إضافة عملية")
    }
}
