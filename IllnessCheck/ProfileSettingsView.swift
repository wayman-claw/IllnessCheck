import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var appSettings: AppSettings

    var body: some View {
        Form {
            Section("Profil") {
                Picker("Geschlecht", selection: Binding(
                    get: { appSettings.userSex },
                    set: { appSettings.userSex = $0 }
                )) {
                    ForEach(UserSex.allCases) { sex in
                        Text(sex.title).tag(sex)
                    }
                }

                if appSettings.userSex == .female {
                    Toggle("Zyklus-Tracking aktivieren", isOn: Binding(
                        get: { appSettings.cycleTrackingEnabled },
                        set: { appSettings.cycleTrackingEnabled = $0 }
                    ))
                }
            }

            Section("Beschwerden") {
                NavigationLink {
                    SymptomCategoriesSettingsView()
                } label: {
                    Label("Symptom-Kategorien", systemImage: "list.bullet.rectangle")
                }
            }

            Section("Hinweis") {
                Text("Die optionale Zyklus-Sektion wird nur eingeblendet, wenn das Profil auf weiblich steht und Zyklus-Tracking aktiviert wurde.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profil")
    }
}
