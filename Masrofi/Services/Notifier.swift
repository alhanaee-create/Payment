import UserNotifications

enum Notifier {
    static let settingKey = "notifyOnLog"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func notifyLogged(amount: String, merchant: String) async {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "تم تسجيل مصروف ✅"
        content.body = "\(amount) — \(merchant)"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
