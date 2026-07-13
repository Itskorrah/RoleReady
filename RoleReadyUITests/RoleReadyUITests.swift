import XCTest

final class RoleReadyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSampleWorkspaceShowsCompletePreparationLoop() {
        app = launchApp()
        startSampleWorkspace()

        XCTAssertTrue(element("active-role-card").waitForExistence(timeout: 3))
        app.tabBars.buttons["Evidence"].tap()
        XCTAssertTrue(element("evidence.overview").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Rebuilt a legacy SAS workflow in Python"].exists)

        app.tabBars.buttons["Roles"].tap()
        XCTAssertTrue(element("roles.list").waitForExistence(timeout: 3))
        app.staticTexts["Senior Data Engineer"].firstMatch.tap()
        XCTAssertTrue(element("roleDetail.loaded").waitForExistence(timeout: 3))
        app.buttons["roleDetail.matchReport"].tap()
        XCTAssertTrue(element("matchReport.loaded").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Strong proof"].firstMatch.exists)
    }

    @MainActor
    func testPracticeDeckRevealsCuesWithoutPresentingAsLiveAssistance() {
        app = launchApp()
        startSampleWorkspace()
        app.tabBars.buttons["Practise"].tap()

        XCTAssertTrue(element("practice-home").waitForExistence(timeout: 3))
        app.buttons["Start a 5-minute practice"].tap()
        XCTAssertTrue(element("prep-deck").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Practice before the interview"].exists)
        app.buttons["reveal-practice-cues"].tap()
        XCTAssertTrue(app.staticTexts["MEMORY CUES"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "133")).firstMatch.exists)
    }

    @MainActor
    func testRequirementContextFlowsIntoSavedAndReopenedAnswer() {
        app = launchApp()
        startSampleWorkspace()
        app.tabBars.buttons["Roles"].tap()
        app.staticTexts["Senior Data Engineer"].firstMatch.tap()
        app.buttons["roleDetail.matchReport"].tap()
        XCTAssertTrue(element("matchReport.loaded").waitForExistence(timeout: 5))

        let buildAnswer = app.buttons["Build answer"].firstMatch
        XCTAssertTrue(buildAnswer.waitForExistence(timeout: 2))
        buildAnswer.tap()
        XCTAssertTrue(element("answer-studio").waitForExistence(timeout: 3))
        let questionField = element("answer-question")
        XCTAssertTrue(questionField.waitForExistence(timeout: 2))
        XCTAssertTrue(String(describing: questionField.value).localizedCaseInsensitiveContains("build and maintain"))

        app.buttons["generate-answer"].tap()
        XCTAssertTrue(element("answer-content").waitForExistence(timeout: 3))
        app.switches["confirm-answer-facts"].tap()
        app.buttons["save-answer"].tap()

        app.tabBars.buttons["Practise"].tap()
        let savedQuestion = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "build and maintain")).firstMatch
        XCTAssertTrue(savedQuestion.waitForExistence(timeout: 3))
        savedQuestion.tap()
        XCTAssertTrue(app.navigationBars["Edit answer"].waitForExistence(timeout: 3))
        XCTAssertTrue(element("answer-content").exists)
    }

    @MainActor
    func testCanCaptureACompleteStoryFromBlankWorkspace() {
        app = launchApp()
        advanceToPrivacyPage()
        app.buttons["start-blank-workspace"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))

        app.buttons["global-compose"].tap()
        app.buttons["Capture a story"].tap()
        XCTAssertTrue(element("experienceEditor.root").waitForExistence(timeout: 3))

        type("experienceEditor.title", "Recovered a delayed client report")
        type("experienceEditor.organisation", "Northstar Services")
        app.buttons["experienceEditor.continue"].tap()

        type("experienceEditor.situation", "A weekly client report was delayed after a source-system change created invalid records.")
        type("experienceEditor.task", "I owned the diagnosis and needed to restore the report before the client review.")
        app.buttons["experienceEditor.continue"].tap()

        type("experienceEditor.action.0", "I traced the invalid records, documented the changed rule, and added a validation check before rerunning the report.")
        let capability = element("experienceEditor.capability.technicalProblemSolving")
        if !capability.isHittable { app.swipeUp() }
        capability.tap()
        app.buttons["experienceEditor.continue"].tap()

        type("experienceEditor.result", "The corrected report was delivered before the client review and the validation check passed.")
        type("experienceEditor.evidence", "The delivery timestamp and validation log confirmed the outcome.")
        app.buttons["experienceEditor.continue"].tap()

        XCTAssertTrue(element("experienceEditor.review").waitForExistence(timeout: 2))
        app.buttons["experienceEditor.save"].tap()

        app.tabBars.buttons["Evidence"].tap()
        XCTAssertTrue(app.staticTexts["Recovered a delayed client report"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testOnboardingPrimaryActionsRemainReachableAtAccessibilityTextSize() {
        app = launchApp(extraArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])

        XCTAssertTrue(element("onboarding-promise").waitForExistence(timeout: 3))
        tapAfterScrolling(app.buttons["See how it works"])
        XCTAssertTrue(element("onboarding-evidence").waitForExistence(timeout: 2))
        tapAfterScrolling(app.buttons["Privacy first"])
        XCTAssertTrue(element("onboarding-privacy").waitForExistence(timeout: 2))
        tapAfterScrolling(app.buttons["start-blank-workspace"])
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func startSampleWorkspace() {
        advanceToPrivacyPage()
        app.buttons["start-sample-workspace"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func advanceToPrivacyPage() {
        XCTAssertTrue(element("onboarding-promise").waitForExistence(timeout: 3))
        app.buttons["See how it works"].tap()
        XCTAssertTrue(element("onboarding-evidence").waitForExistence(timeout: 2))
        app.buttons["Privacy first"].tap()
        XCTAssertTrue(element("onboarding-privacy").waitForExistence(timeout: 2))
    }

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func type(_ identifier: String, _ text: String) {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: 2), "Missing field \(identifier)")
        if !field.isHittable { app.swipeUp() }
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"] + extraArguments
        application.launch()
        return application
    }

    @MainActor
    private func tapAfterScrolling(_ control: XCUIElement) {
        XCTAssertTrue(control.waitForExistence(timeout: 2))
        for _ in 0..<5 where !control.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(control.isHittable)
        control.tap()
    }
}
