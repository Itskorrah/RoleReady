import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private enum Key {
        static let onboarding = "roleready.onboarding.complete"
        static let haptics = "roleready.haptics.enabled"
        static let sampleWorkspace = "roleready.sample.enabled"
    }

    var selectedTab: AppTab = .today
    var presentedSheet: SheetDestination?
    var toast: ToastMessage?
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarding) }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) }
    }
    var isUsingSampleWorkspace: Bool {
        didSet { defaults.set(isUsingSampleWorkspace, forKey: Key.sampleWorkspace) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let selectedDefaults: UserDefaults
        if let defaults {
            selectedDefaults = defaults
        } else if isUITesting {
            let suiteName = "com.roleready.uitests.preferences"
            selectedDefaults = UserDefaults(suiteName: suiteName) ?? .standard
            selectedDefaults.removePersistentDomain(forName: suiteName)
        } else {
            selectedDefaults = .standard
        }
        self.defaults = selectedDefaults
        self.hasCompletedOnboarding = selectedDefaults.bool(forKey: Key.onboarding)
        self.hapticsEnabled = selectedDefaults.object(forKey: Key.haptics) as? Bool ?? true
        self.isUsingSampleWorkspace = selectedDefaults.bool(forKey: Key.sampleWorkspace)
    }

    func completeOnboarding(usingSample: Bool) {
        isUsingSampleWorkspace = usingSample
        hasCompletedOnboarding = true
    }

    func showToast(_ title: String, symbol: String = "checkmark.circle.fill") {
        toast = ToastMessage(title: title, symbol: symbol)
    }

    func resetAfterDataDeletion() {
        hasCompletedOnboarding = false
        isUsingSampleWorkspace = false
        hapticsEnabled = true
        defaults.removeObject(forKey: Key.onboarding)
        defaults.removeObject(forKey: Key.sampleWorkspace)
        defaults.removeObject(forKey: Key.haptics)
    }
}

struct ToastMessage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let symbol: String
}
