import Foundation
import LocalAuthentication
import Observation

enum AppLockState: Equatable {
    case unconfigured
    case locked
    case unlocking
    case unlocked
    case unavailable(String)

    var isUnlocked: Bool {
        switch self {
        case .unconfigured, .unlocked: true
        case .locked, .unlocking, .unavailable: false
        }
    }
}

@MainActor
@Observable
final class AppLockController {
    private enum Key { static let enabled = "roleready.app-lock.enabled" }

    private(set) var state: AppLockState
    private(set) var isEnabled: Bool
    var isPrivacyShieldVisible = false
    var lastError: String?

    private let defaults: UserDefaults
    private var context: LAContext?

    init(defaults: UserDefaults? = nil) {
        let selectedDefaults: UserDefaults
        if let defaults {
            selectedDefaults = defaults
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            selectedDefaults = UserDefaults(suiteName: "com.roleready.uitests.preferences") ?? .standard
        } else {
            selectedDefaults = .standard
        }
        self.defaults = selectedDefaults
        self.isEnabled = selectedDefaults.bool(forKey: Key.enabled)
        self.state = selectedDefaults.bool(forKey: Key.enabled) ? .locked : .unconfigured
    }

    func sceneBecameInactive() {
        isPrivacyShieldVisible = true
        guard isEnabled, state != .unlocking else { return }
        state = .locked
    }

    func sceneBecameActive() async {
        isPrivacyShieldVisible = false
        if isEnabled, state == .locked {
            await unlock()
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let authenticated = await authenticate(reason: "Enable App Lock to protect your career evidence")
            guard authenticated else {
                state = .unconfigured
                return false
            }
            isEnabled = true
            state = .unlocked
            defaults.set(true, forKey: Key.enabled)
            return true
        }

        guard await authenticate(reason: "Authenticate to turn off App Lock") else {
            if case .unavailable = state {
                return false
            }
            state = .unlocked
            return false
        }
        isEnabled = false
        state = .unconfigured
        defaults.set(false, forKey: Key.enabled)
        return true
    }

    func unlock() async {
        guard isEnabled else {
            state = .unconfigured
            return
        }
        if await authenticate(reason: "Unlock your RoleReady evidence") {
            state = .unlocked
        } else if case .unavailable = state {
            return
        } else {
            state = .locked
        }
    }

    func lockNow() {
        guard isEnabled else { return }
        context?.invalidate()
        context = nil
        state = .locked
    }

    func resetAfterDataDeletion() {
        context?.invalidate()
        context = nil
        defaults.removeObject(forKey: Key.enabled)
        isEnabled = false
        isPrivacyShieldVisible = false
        lastError = nil
        state = .unconfigured
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Not now"
        self.context = context
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let message = "Set a device passcode or biometric unlock before enabling App Lock."
            lastError = error?.localizedDescription ?? message
            state = .unavailable(message)
            self.context = nil
            return false
        }

        state = .unlocking
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            self.context = nil
            lastError = nil
            return success
        } catch {
            self.context = nil
            lastError = error.localizedDescription
            return false
        }
    }
}
