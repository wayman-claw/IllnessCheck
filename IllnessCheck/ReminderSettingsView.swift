import SwiftUI

struct ReminderSettingsView: View {
    @EnvironmentObject private var reminderManager: ReminderManager

    var body: some View {
        Form {
            Section("Daily Reminder") {
                Toggle("Enable reminder", isOn: $reminderManager.reminderEnabled)
                    .onChange(of: reminderManager.reminderEnabled) { _, newValue in
                        Task {
                            if newValue {
                                await reminderManager.requestAuthorization()
                            }
                            await reminderManager.scheduleDailyReminder()
                        }
                    }

                DatePicker("Time", selection: $reminderManager.reminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: reminderManager.reminderTime) { _, _ in
                        Task {
                            await reminderManager.scheduleDailyReminder()
                        }
                    }
            }

            Section("Why this exists") {
                Text("The app is designed to make daily tracking easy enough to finish in under a minute before bedtime.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Reminders")
    }
}
