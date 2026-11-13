import AppIntents

struct MasrofiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "سجّل مصروف في \(.applicationName)",
                "Log expense in \(.applicationName)",
            ],
            shortTitle: "سجّل مصروف",
            systemImageName: "creditcard"
        )
    }
}
