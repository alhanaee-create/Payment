import SwiftUI
import SwiftData

@main
struct MasrofiApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
        }
        .modelContainer(Store.container)
    }
}
