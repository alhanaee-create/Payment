import SwiftUI
import SwiftData
import MapKit

struct MapTabView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var selection: PersistentIdentifier?
    @State private var range: TimeRange = .month
    @State private var position: MapCameraPosition = .automatic

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "هذا الأسبوع"
        case month = "هذا الشهر"
        case all = "الكل"
        var id: String { rawValue }
    }

    private struct Pin: Identifiable {
        let expense: Expense
        let coordinate: CLLocationCoordinate2D
        var id: PersistentIdentifier { expense.persistentModelID }
    }

    private var pins: [Pin] {
        let cal = Calendar.current
        return expenses.compactMap { e in
            guard let c = e.coordinate else { return nil }
            switch range {
            case .week: guard cal.isDate(e.date, equalTo: .now, toGranularity: .weekOfYear) else { return nil }
            case .month: guard cal.isDate(e.date, equalTo: .now, toGranularity: .month) else { return nil }
            case .all: break
            }
            return Pin(expense: e, coordinate: c)
        }
    }

    private var selected: Expense? {
        pins.first { $0.id == selection }?.expense
    }

    var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selection) {
                ForEach(pins) { pin in
                    Marker(pin.expense.formattedAmount, systemImage: pin.expense.category.icon, coordinate: pin.coordinate)
                        .tint(pin.expense.category.color)
                        .tag(pin.id)
                }
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .safeAreaInset(edge: .top) {
                Picker("الفترة", selection: $range) {
                    ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom) {
                if let expense = selected {
                    NavigationLink(value: expense) {
                        ExpenseRow(expense: expense)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            }
            .onChange(of: range) { _, _ in
                selection = nil
                position = .automatic
            }
            .navigationDestination(for: Expense.self) { ExpenseDetailView(expense: $0) }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if pins.isEmpty {
                    ContentUnavailableView("ما فيه عمليات على الخريطة", systemImage: "map",
                                           description: Text("العمليات اللي فيها موقع تطلع هنا."))
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .padding(40)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
