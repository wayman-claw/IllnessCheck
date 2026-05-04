import SwiftUI
import SwiftData

@main
struct IllnessCheckApp: App {
    @StateObject private var reminderManager = ReminderManager()
    @StateObject private var deepLinkManager = DeepLinkManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var storeRecoveryAnnouncer: StoreRecoveryAnnouncer

    let sharedModelContainer: ModelContainer

    init() {
        let bootstrap = StoreBootstrap.makeContainer()
        self.sharedModelContainer = bootstrap.container
        _storeRecoveryAnnouncer = StateObject(wrappedValue: StoreRecoveryAnnouncer(event: bootstrap.event))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(reminderManager)
                .environmentObject(deepLinkManager)
                .environmentObject(appSettings)
                .environmentObject(storeRecoveryAnnouncer)
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
