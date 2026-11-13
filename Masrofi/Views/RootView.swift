import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ExpensesListView()
                .tabItem { Label("العمليات", systemImage: "list.bullet.rectangle") }
            StatsView()
                .tabItem { Label("الإحصائيات", systemImage: "chart.pie.fill") }
            MapTabView()
                .tabItem { Label("الخريطة", systemImage: "map.fill") }
            SettingsView()
                .tabItem { Label("الإعداد", systemImage: "gearshape.fill") }
        }
        .task {
            LocationService.shared.requestPermission()
            await Notifier.requestPermission()
        }
    }
}
