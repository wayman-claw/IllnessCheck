import SwiftUI
import SwiftData

@main
struct IllnessCheckApp: App {
    @StateObject private var reminderManager = ReminderManager()
    @StateObject private var deepLinkManager = DeepLinkManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyEntry.self,
            SymptomEntry.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("Primary SwiftData container creation failed: \(error)")

            do {
                try SwiftDataStoreResetter.resetDefaultStoreFiles()
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                do {
                    let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
                } catch {
                    fatalError("Could not create ModelContainer even after reset fallback: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(reminderManager)
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handle(url: url)
                }
                .onChange(of: reminderManager.pendingRoute) { _, route in
                    guard route == .todayCheckIn else { return }
                    deepLinkManager.pendingRoute = .todayCheckIn
                    reminderManager.consumePendingRoute()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

enum SwiftDataStoreResetter {
    static func resetDefaultStoreFiles() throws {
        let fileManager = FileManager.default
        let supportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        let candidateNames = [
            "default.store",
            "default.store-shm",
            "default.store-wal",
            "IllnessCheck.store",
            "IllnessCheck.store-shm",
            "IllnessCheck.store-wal"
        ]

        for name in candidateNames {
            let fileURL = supportURL.appendingPathComponent(name)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
