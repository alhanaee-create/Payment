import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage(Notifier.settingKey) private var notifyOnLog = true
    @AppStorage(Budget.key) private var budget: Double = 0
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("التسجيل التلقائي مع Apple Pay", systemImage: "wave.3.right.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                        Text("سوّ هذي الخطوات مرة وحدة بس، وبعدها كل ما تدفع بجوالك تنسجل العملية لحالها مع المبلغ والمتجر والمكان.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("الخطوات") {
                    Step(n: 1, text: "افتح تطبيق **الاختصارات** ← تبويب **الأتمتة** ← اضغط **+** (أو «أتمتة جديدة»).")
                    Step(n: 2, text: "اختر **المعاملة** (Transaction).")
                    Step(n: 3, text: "حدّد بطاقاتك كلها، واختر **تشغيل فوراً** (Run Immediately)، واضغط **التالي**.")
                    Step(n: 4, text: "اختر **أتمتة فارغة جديدة**، وأضف إجراء **الحصول على الموقع الحالي** (Get Current Location).")
                    Step(n: 5, text: "أضف إجراء **سجّل مصروف** من تطبيق **مصروفي**.")
                    Step(n: 6, text: "اضغط على كل خانة في الإجراء واختر:\n• **المبلغ** ← مدخلات الاختصار ← المبلغ\n• **المتجر** ← مدخلات الاختصار ← التاجر\n• **البطاقة** ← مدخلات الاختصار ← البطاقة أو البطاقة المخزنة\n• **الموقع** ← الموقع الحالي")
                    Step(n: 7, text: "اضغط **تم**. خلاص! جرّب ادفع أي شي بـ Apple Pay وشوف العملية تطلع هنا 🎉")

                    Button {
                        if let url = URL(string: "shortcuts://") { openURL(url) }
                    } label: {
                        Label("افتح تطبيق الاختصارات", systemImage: "arrow.up.forward.app.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack {
                        Label("الميزانية", systemImage: "target")
                        Spacer()
                        TextField("بدون", value: $budget, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(maxWidth: 140)
                        Text(Fmt.defaultCurrency)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("الميزانية الشهرية")
                } footer: {
                    Text("لو حطيت ميزانية، الصفحة الرئيسية بتوريك كم باقي لك وكم تقدر تصرف باليوم. خلّها فاضية أو صفر عشان تخفيها.")
                }

                Section {
                    Button {
                        LocationService.shared.requestPermission()
                    } label: {
                        Label("اسمح بالوصول للموقع", systemImage: "location.fill")
                    }
                    Button {
                        Task { await Notifier.requestPermission() }
                    } label: {
                        Label("اسمح بالإشعارات", systemImage: "bell.badge.fill")
                    }
                    Toggle(isOn: $notifyOnLog) {
                        Label("إشعار بعد كل تسجيل", systemImage: "bell")
                    }
                } header: {
                    Text("الأذونات")
                } footer: {
                    Text("الإشعار يذكّرك تضيف صورة الفاتورة أو ملاحظة للعملية.")
                }

                Section("بياناتك") {
                    ShareLink(
                        item: CSVExport(text: CSVExport.build(from: expenses)),
                        preview: SharePreview("مصروفي.csv")
                    ) {
                        Label("صدّر العمليات (Excel / Numbers)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(expenses.isEmpty)
                    LabeledContent("عدد العمليات", value: "\(expenses.count)")
                }

                Section {
                    Text("مصروفي يحفظ بياناتك على جوالك بس، وما يرسلها لأي مكان. التطبيق ما يقدر يشوف حسابك البنكي — هو يسجّل اللي يرسله له الاختصار وقت الدفع.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("الإعداد")
        }
    }
}

private struct Step: View {
    let n: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

struct CSVExport: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Masrofi.csv")
            // BOM عشان Excel يقرأ العربي صح.
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(Data(export.text.utf8))
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    static func build(from expenses: [Expense]) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
        df.timeZone = .current
        var lines = ["التاريخ,المبلغ,العملة,المتجر,التصنيف,البطاقة,المكان,خط العرض,خط الطول,ملاحظة"]
        for e in expenses {
            let fields: [String] = [
                df.string(from: e.date),
                String(format: "%.2f", e.amount),
                e.currency.isEmpty ? Fmt.defaultCurrency : e.currency,
                e.merchant,
                e.category.title,
                e.card,
                e.placeName,
                e.latitude.map { String($0) } ?? "",
                e.longitude.map { String($0) } ?? "",
                e.note,
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ s: String) -> String {
        if s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}
