import XCTest
@testable import RoleReady

@MainActor
final class AppStateTests: XCTestCase {
    func testDataDeletionResetsPreferencesAndAppLock() {
        let suiteName = "com.roleready.tests.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "roleready.onboarding.complete")
        defaults.set(false, forKey: "roleready.haptics.enabled")
        defaults.set(true, forKey: "roleready.sample.enabled")
        defaults.set(true, forKey: "roleready.app-lock.enabled")

        let appState = AppState(defaults: defaults)
        let appLock = AppLockController(defaults: defaults)
        XCTAssertTrue(appState.hasCompletedOnboarding)
        XCTAssertFalse(appState.hapticsEnabled)
        XCTAssertTrue(appState.isUsingSampleWorkspace)
        XCTAssertTrue(appLock.isEnabled)

        appLock.resetAfterDataDeletion()
        appState.resetAfterDataDeletion()

        XCTAssertFalse(appState.hasCompletedOnboarding)
        XCTAssertTrue(appState.hapticsEnabled)
        XCTAssertFalse(appState.isUsingSampleWorkspace)
        XCTAssertFalse(appLock.isEnabled)
        XCTAssertEqual(appLock.state, .unconfigured)
        XCTAssertNil(defaults.object(forKey: "roleready.onboarding.complete"))
        XCTAssertNil(defaults.object(forKey: "roleready.haptics.enabled"))
        XCTAssertNil(defaults.object(forKey: "roleready.sample.enabled"))
        XCTAssertNil(defaults.object(forKey: "roleready.app-lock.enabled"))
    }
}
