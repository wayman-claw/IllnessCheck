import Foundation

@MainActor
final class DeepLinkManager: ObservableObject {
    enum Route: Equatable {
        case todayCheckIn
    }

    @Published var pendingRoute: Route?

    func handle(url: URL) {
        guard url.scheme == "illnesscheck" else { return }

        if url.host == "checkin" {
            pendingRoute = .todayCheckIn
        }
    }

    func consume(route: Route) {
        if pendingRoute == route {
            pendingRoute = nil
        }
    }
}
