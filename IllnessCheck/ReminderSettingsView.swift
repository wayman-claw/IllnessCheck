import SwiftUI

struct ReminderSettingsView: View {
    @EnvironmentObject private var reminderManager: ReminderManager

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder")
                        .font(.largeTitle.bold())
                    Text("Plane eine Erinnerung für morgens, abends oder jede andere Uhrzeit, die für dich funktioniert.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.18), Color.pink.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )

                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Erinnerung aktivieren", isOn: $reminderManager.reminderEnabled)
                        .onChange(of: reminderManager.reminderEnabled) { _, newValue in
                            Task {
                                if newValue {
                                    await reminderManager.requestAuthorization()
                                }
                                await reminderManager.scheduleDailyReminder()
                            }
                        }

                    DatePicker("Uhrzeit", selection: $reminderManager.reminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderManager.reminderTime) { _, _ in
                            Task {
                                await reminderManager.scheduleDailyReminder()
                            }
                        }
                }
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Warum das hilfreich ist")
                        .font(.headline)
                    Text("Die App ist darauf ausgelegt, den Tages-Check-in in ungefähr einer Minute vor dem Schlafengehen zu erledigen.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Reminder")
        .navigationBarTitleDisplayMode(.inline)
    }
}
