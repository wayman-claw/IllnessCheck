import Foundation
import UserNotifications

@MainActor
final class ReminderManager: NSObject, ObservableObject {
    @Published var reminderEnabled: Bool = false
    @Published var reminderTime: Date = Date()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            reminderEnabled = granted
        } catch {
            print("Notification auth failed: \(error)")
        }
    }

    func scheduleDailyReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-health-reminder"])

        guard reminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Daily Check-In"
        content.body = "Direkt den heutigen Eintrag öffnen und den Tag kurz festhalten."
        content.sound = .default
        content.userInfo = ["deeplink": "illnesscheck://checkin/today"]

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-health-reminder", content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("Scheduling reminder failed: \(error)")
        }
    }
}

extension ReminderManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let deepLink = response.notification.request.content.userInfo["deeplink"] as? String,
              let url = URL(string: deepLink) else { return }

        await MainActor.run {
            NotificationCenter.default.post(name: .illnessCheckDeepLinkOpened, object: url)
        }
    }
}

extension Notification.Name {
    static let illnessCheckDeepLinkOpened = Notification.Name("illnessCheckDeepLinkOpened")
}
