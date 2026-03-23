import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("profile.userSex") var userSexRaw: String = UserSex.undisclosed.rawValue
    @AppStorage("profile.cycleTrackingEnabled") var cycleTrackingEnabled: Bool = false

    var userSex: UserSex {
        get { UserSex(rawValue: userSexRaw) ?? .undisclosed }
        set {
            userSexRaw = newValue.rawValue
            if newValue != .female && cycleTrackingEnabled {
                cycleTrackingEnabled = false
            }
        }
    }

    var shouldShowCycleSection: Bool {
        userSex == .female && cycleTrackingEnabled
    }
}
