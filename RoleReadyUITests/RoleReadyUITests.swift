import XCTest

final class RoleReadyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSampleWorkspaceShowsExamplesRolesAndHonestMatching() {
        app = launchApp()
        startSampleWorkspace()

        XCTAssertTrue(element("active-role-card").waitForExistence(timeout: 4))
        capture("01-prepare-dashboard")

        tapTab("My Examples")
        XCTAssertTrue(element("evidence.overview").waitForExistence(timeout: 4))
        let anyExampleRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "evidence.row."))
            .firstMatch
        XCTAssertTrue(anyExampleRow.waitForExistence(timeout: 3))
        capture("02-my-examples")

        tapTab("Prepare")
        tapAfterScrolling(app.buttons["saved-roles-card"])
        XCTAssertTrue(element("roleDetail.root").waitForExistence(timeout: 4))
        app.buttons["roleDetail.matchReport"].tap()
        XCTAssertTrue(element("matchReport.root").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Direct evidence"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+%" )).firstMatch.exists)
        capture("04-honest-match")
    }

    @MainActor
    func testPracticeDeckRevealsCuesWithoutPresentingAsLiveAssistance() {
        app = launchApp()
        startSampleWorkspace()
        tapTab("Practise")

        XCTAssertTrue(element("practice-home").waitForExistence(timeout: 4))
        let start = app.buttons["Start a 5-minute practice"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        XCTAssertTrue(start.isEnabled)
        start.tap()
        XCTAssertTrue(element("prep-deck").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Practice before the interview"].exists)
        app.buttons["reveal-practice-cues"].tap()
        XCTAssertTrue(app.staticTexts["MEMORY CUES"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "133")).firstMatch.exists)
        capture("06-practice-cues")
    }

    @MainActor
    func testFirstUsePreparationPathCreatesApprovesAndPractisesGroundedAnswer() {
        app = launchApp()
        XCTAssertTrue(element("onboarding-promise").waitForExistence(timeout: 4))
        capture("00-onboarding")
        let startBlankWorkspace = element("start-blank-workspace")
        tapAfterScrolling(startBlankWorkspace)
        if !element("preparation-flow").waitForExistence(timeout: 4) {
            tapAfterScrolling(startBlankWorkspace)
        }
        XCTAssertTrue(element("preparation-flow").waitForExistence(timeout: 8))

        type("career-history-text", """
        Senior Program Officer | Community Services Branch | 2024
        • I coordinated policy, service and operations staff to map a delayed grants assessment process and identify the highest-risk handoffs.
        • I chose a staged pilot because applications still needed to be processed, then facilitated workshops and tested the revised guidance with assessors.
        • I documented decisions, tracked issues and adjusted the workflow after staff feedback before briefing the branch leadership team.
        • The branch approved the revised process, assessors reported fewer avoidable handoffs, and the pilot was adopted for the next grants round.
        """)
        tapAfterScrolling(element("analyse-career-history"))

        XCTAssertTrue(element("draft-example-title").waitForExistence(timeout: 6))
        capture("02-career-draft-review")
        let useReviewedExample = element("use-reviewed-example")
        // The action sits immediately below a large adaptive review card. Bring
        // the lazy scroll content into the accessibility tree before querying it.
        element("preparation-scroll").swipeUp()
        XCTAssertTrue(
            useReviewedExample.waitForExistence(timeout: 4)
                && useReviewedExample.waitForEnabled(timeout: 4)
        )
        tapAfterScrolling(useReviewedExample)
        XCTAssertTrue(element("preparation-job-text").waitForExistence(timeout: 8))

        type("preparation-job-text", """
        Senior Program Officer
        Department of Community Services
        Key requirements
        • Demonstrated experience improving public services while maintaining quality and delivery continuity.
        • Build productive stakeholder relationships and facilitate agreement across policy and operational teams.
        • Use sound judgement to plan work, manage risks and deliver clear written advice to senior leaders.
        """)
        tapAfterScrolling(element("analyse-role-source"))

        XCTAssertTrue(element("preparation-role-title").waitForExistence(timeout: 6))
        capture("03-requirement-review")
        tapAfterScrolling(element("save-and-match-role"))
        XCTAssertTrue(element("preparation-match-result").waitForExistence(timeout: 7))
        XCTAssertTrue(
            app.staticTexts["Direct evidence"].firstMatch.exists
                || app.staticTexts["Transferable"].firstMatch.exists
        )
        capture("04-role-specific-match")

        tapAfterScrolling(element("preparation-back"))
        XCTAssertTrue(element("preparation-role-title").waitForExistence(timeout: 4))
        tapAfterScrolling(element("save-and-match-role"))
        XCTAssertTrue(element("preparation-match-result").waitForExistence(timeout: 7))

        typeIfPresent("strengthen-task", "I coordinated the process review and was responsible for briefing the branch on a workable recommendation.")
        typeIfPresent("strengthen-rationale", "it protected service continuity while giving assessors a safe way to validate the revised guidance")
        let addReason = app.buttons["Add this reason to my actions"]
        if addReason.waitForExistence(timeout: 1), addReason.isEnabled {
            tapAfterScrolling(addReason)
        }
        typeIfPresent("strengthen-evidence", "The branch approval, pilot issue log and assessor feedback confirmed that the revised process worked as intended.")
        typeIfPresent("strengthen-learning", "I learnt to agree the continuity constraints and success checks before asking stakeholders to redesign a live service.")

        tapAfterScrolling(element("continue-to-grounded-answer"))
        XCTAssertTrue(element("answer-studio").waitForExistence(timeout: 6))
        tapAfterScrolling(element("generate-answer"))
        XCTAssertTrue(element("answer-content").waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Where each claim came from"].waitForExistence(timeout: 3))

        let supportedClaim = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND label BEGINSWITH %@",
                "answer-claim-supported",
                "Supported by Question context."
            )
        ).firstMatch
        XCTAssertTrue(supportedClaim.waitForExistence(timeout: 3))
        tapAfterScrolling(supportedClaim)
        XCTAssertTrue(element("source-claim-sheet").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["SUPPORTING EVIDENCE"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(element("source-claim-sheet").waitForNonExistence(timeout: 4))
        capture("05-grounded-answer")

        setToggle("confirm-answer-facts", on: true)
        let saveAnswer = element("save-answer")
        XCTAssertTrue(saveAnswer.waitForEnabled(timeout: 3))
        tapAfterScrolling(saveAnswer)

        XCTAssertTrue(element("guided-practice").waitForExistence(timeout: 7))
        app.buttons["guided-reveal-cues"].tap()
        XCTAssertTrue(app.staticTexts["MEMORY CUES"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Questions the panel may ask next"].waitForExistence(timeout: 3))
        capture("06-guided-practice")
    }

    @MainActor
    func testCanCaptureACompleteExampleFromBlankWorkspace() {
        app = launchApp()
        XCTAssertTrue(element("onboarding-promise").waitForExistence(timeout: 4))
        tapAfterScrolling(element("start-example-library"))
        XCTAssertTrue(element("experienceEditor.root").waitForExistence(timeout: 4))

        type("experienceEditor.title", "Recovered a delayed client report")
        type("experienceEditor.organisation", "Northstar Services")
        tapAfterScrolling(element("experienceEditor.continue"))

        type("experienceEditor.situation", "A weekly client report was delayed after a source-system change created invalid records.")
        type("experienceEditor.task", "I owned the diagnosis and needed to restore the report before the client review.")
        tapAfterScrolling(element("experienceEditor.continue"))

        type("experienceEditor.action.0", "I traced the invalid records, documented the changed rule, and added a validation check before rerunning the report.")
        tapAfterScrolling(element("experienceEditor.capability.technicalProblemSolving"))
        tapAfterScrolling(element("experienceEditor.continue"))

        type("experienceEditor.result", "The corrected report was delivered before the client review and the validation check passed.")
        type("experienceEditor.evidence", "The delivery timestamp and validation log confirmed the outcome.")
        tapAfterScrolling(element("experienceEditor.continue"))

        XCTAssertTrue(element("experienceEditor.review").waitForExistence(timeout: 3))
        tapAfterScrolling(element("experienceEditor.save"))

        XCTAssertTrue(app.navigationBars["Prepare"].waitForExistence(timeout: 4))
        tapTab("My Examples")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Recovered a delayed client report")).firstMatch.waitForExistence(timeout: 4))
    }

    @MainActor
    func testOnboardingPrimaryActionRemainsReachableAtAccessibilityTextSize() {
        app = launchApp(extraArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])

        XCTAssertTrue(element("onboarding-promise").waitForExistence(timeout: 4))
        XCTAssertTrue(element("onboarding-trust").exists)
        tapAfterScrolling(element("start-blank-workspace"))
        XCTAssertTrue(element("preparation-flow").waitForExistence(timeout: 5))
        XCTAssertTrue(element("career-history-text").waitForExistence(timeout: 3))
    }

    @MainActor
    func testOnboardingSupportsDarkAppearance() {
        app = launchApp(extraArguments: ["-AppleInterfaceStyle", "Dark"])

        XCTAssertTrue(element("onboarding-promise").waitForExistence(timeout: 4))
        XCTAssertTrue(element("onboarding-trust").exists)
        XCTAssertTrue(element("start-blank-workspace").exists)
        capture("00-onboarding-dark")
    }

    @MainActor
    private func startSampleWorkspace() {
        XCTAssertTrue(element("onboarding-promise").waitForExistence(timeout: 4))
        tapAfterScrolling(element("start-sample-workspace"))
        XCTAssertTrue(app.navigationBars["Prepare"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func type(_ identifier: String, _ text: String) {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: 4), "Missing field \(identifier)")
        dismissEditorKeyboardIfAvailable()
        tapAfterScrolling(field)
        if !field.waitForKeyboardFocus(timeout: 2) {
            // A preceding keyboard dismissal can consume the first tap while
            // SwiftUI completes the next-step transition. Retry once.
            field.tap()
        }
        XCTAssertTrue(field.waitForKeyboardFocus(timeout: 4), "Field \(identifier) did not receive keyboard focus")
        field.typeText(text)
        dismissEditorKeyboardIfAvailable()
    }

    @MainActor
    private func typeIfPresent(_ identifier: String, _ text: String) {
        let field = element(identifier)
        guard field.waitForExistence(timeout: 1) else { return }
        dismissEditorKeyboardIfAvailable()
        tapAfterScrolling(field)
        if !field.waitForKeyboardFocus(timeout: 2) {
            field.tap()
        }
        XCTAssertTrue(field.waitForKeyboardFocus(timeout: 4), "Field \(identifier) did not receive keyboard focus")
        field.typeText(text)
        dismissEditorKeyboardIfAvailable()
    }

    @MainActor
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"] + extraArguments
        application.launch()
        return application
    }

    @MainActor
    private func dismissEditorKeyboardIfAvailable() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let done = app.toolbars.buttons["Done"]
        if done.waitForExistence(timeout: 2), done.isHittable {
            done.tap()
            _ = keyboard.waitForNonExistence(timeout: 2)
        }
    }

    @MainActor
    private func tapAfterScrolling(_ control: XCUIElement) {
        guard scrollUntilHittable(control) else {
            XCTFail("Control was not present and hittable after scrolling")
            return
        }
        control.tap()
    }

    @MainActor
    private func tapTab(_ title: String) {
        // iPadOS 26 exposes floating tab items as cells while iPhone exposes
        // the same SwiftUI TabView items as tab-bar buttons. Query by label:
        // the iPad tab identifier is the SF Symbol name, not its visible title.
        let labelPredicate = NSPredicate(format: "label == %@", title)
        let candidates = [
            app.buttons.matching(labelPredicate).firstMatch,
            app.cells.matching(labelPredicate).firstMatch,
            app.popUpButtons.matching(labelPredicate).firstMatch,
            app.otherElements.matching(labelPredicate).firstMatch,
            app.cells[title],
            app.tabBars.buttons[title],
            app.buttons[title],
            app.popUpButtons[title],
            app.otherElements[title]
        ]

        for candidate in candidates where candidate.waitForExistence(timeout: 1) {
            if candidate.isHittable {
                candidate.tap()
                return
            }
        }

        XCTFail("Missing hittable tab named \(title)")
    }

    @MainActor
    @discardableResult
    private func scrollUntilHittable(_ control: XCUIElement) -> Bool {
        for _ in 0..<16 {
            if control.exists, control.isHittable {
                return true
            }
            let scrollCandidates = [
                element("preparation-scroll"),
                element("experienceEditor.form"),
                app.tables.firstMatch,
                app.scrollViews.firstMatch
            ]
            if let scroller = scrollCandidates.first(where: { candidate in
                guard candidate.exists else { return false }
                let frame = candidate.frame
                return frame.width.isFinite && frame.height.isFinite && frame.width > 0 && frame.height > 0
            }) {
                if control.exists {
                    let controlFrame = control.frame
                    if controlFrame.minY.isFinite,
                       controlFrame.midY < scroller.frame.minY + 70 {
                        scroller.swipeDown()
                    } else {
                        scroller.swipeUp()
                    }
                } else {
                    scroller.swipeUp()
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            } else {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
        }
        return control.exists && control.isHittable
    }

    @MainActor
    private func setToggle(_ identifier: String, on: Bool) {
        let toggle = app.switches[identifier]
        XCTAssertTrue(toggle.waitForExistence(timeout: 4), "Missing toggle \(identifier)")
        let desiredValue = on ? "1" : "0"
        if (toggle.value as? String) != desiredValue {
            // SwiftUI exposes both the labelled row and its native switch. The
            // inner control gives XCUITest a stable hit target at every text size.
            let nativeSwitch = toggle.switches.firstMatch
            if nativeSwitch.waitForExistence(timeout: 1) {
                XCTAssertTrue(scrollUntilHittable(nativeSwitch), "Native switch \(identifier) was not hittable")
                nativeSwitch.tap()
            } else {
                XCTAssertTrue(scrollUntilHittable(toggle), "Toggle \(identifier) was not hittable")
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
        }
        XCTAssertTrue(toggle.waitForValue(desiredValue, timeout: 3), "Toggle \(identifier) did not update")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    func waitForKeyboardFocus(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "hasKeyboardFocus == true")
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
            timeout: timeout
        ) == .completed
    }

    func waitForEnabled(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "enabled == true")
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
            timeout: timeout
        ) == .completed
    }

    func waitForValue(_ value: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: self)],
            timeout: timeout
        ) == .completed
    }
}
