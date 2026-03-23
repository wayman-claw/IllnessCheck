import Foundation
import UserNotifications

@MainActor
final class ReminderManager: ObservableObject {
    @Published var reminderEnabled: Bool = false
    @Published var reminderTime: Date = Date()

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
        content.body = "Take a minute to log food, drinks, symptoms and notes for today."
        content.sound = .default

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
