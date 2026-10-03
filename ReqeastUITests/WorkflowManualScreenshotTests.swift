import XCTest

final class WorkflowManualScreenshotTests: XCTestCase {
    func testCaptureManualScreens() throws {
        guard FileManager.default.fileExists(atPath: "/tmp/reqeast-manual-capture") else { throw XCTSkip("Manual screenshot capture is opt-in") }
        continueAfterFailure = false
        for language in ["en", "zh-Hans", "zh-Hant", "ja", "fr", "pt-BR", "es", "ko", "de"] {
            let app = XCUIApplication()
            app.launchArguments = ["-screenshotMode", "-workflowGuideDemo", "-AppleLanguages", "(\(language))", "-AppleLocale", language]
            app.launch()
            UITestHelpers.activateAndWaitForWindow(app)
            let project = UITestHelpers.projectRow(named: "Order API", in: app)
            XCTAssertTrue(project.waitForExistence(timeout: 10)); UITestHelpers.press(project)
            Thread.sleep(forTimeInterval: 0.5)
            let request = UITestHelpers.requestRow(named: "1 Login", in: app)
            XCTAssertTrue(request.waitForExistence(timeout: 5))
            request.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            Thread.sleep(forTimeInterval: 0.5)
            capture(app, language, "editor")
            let workflow = app.buttons["http-workflow-button"].firstMatch
            XCTAssertTrue(workflow.waitForExistence(timeout: 5)); UITestHelpers.press(workflow)
            Thread.sleep(forTimeInterval: 0.5); capture(app, language, "rules")
            UITestHelpers.press(app.descendants(matching: .any)["workflow-comparison-tab"].firstMatch)
            Thread.sleep(forTimeInterval: 0.5); capture(app, language, "comparison")
            let runner = app.descendants(matching: .any)["workflow-runner-tab"].firstMatch
            XCTAssertTrue(runner.waitForExistence(timeout: 5)); UITestHelpers.press(runner)
            Thread.sleep(forTimeInterval: 0.5); capture(app, language, "runner")
            let scroll = app.sheets.scrollViews.firstMatch
            scroll.scroll(byDeltaX: 0, deltaY: -300); Thread.sleep(forTimeInterval: 0.5)
            capture(app, language, "data")
            scroll.swipeUp(); Thread.sleep(forTimeInterval: 0.5)
            capture(app, language, "results")
            UITestHelpers.press(app.buttons["workflow-close"].firstMatch)
            Thread.sleep(forTimeInterval: 0.5)
            let create = UITestHelpers.requestRow(named: "2 Create order", in: app)
            create.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            Thread.sleep(forTimeInterval: 0.5)
            UITestHelpers.press(app.buttons["http-workflow-button"].firstMatch)
            let inspect = app.descendants(matching: .any)["workflow-inspect-tab"].firstMatch
            UITestHelpers.press(inspect); Thread.sleep(forTimeInterval: 0.5)
            Thread.sleep(forTimeInterval: 0.3)
            capture(app, language, "inspect")
            app.sheets.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -300); Thread.sleep(forTimeInterval: 0.5)
            capture(app, language, "preview")
            UITestHelpers.press(app.descendants(matching: .any)["workflow-files-tab"].firstMatch)
            Thread.sleep(forTimeInterval: 0.5); capture(app, language, "files")
            app.terminate()
        }
    }

    private func capture(_ app: XCUIApplication, _ language: String, _ name: String) {
        app.activate()
        let screenshot = app.windows.firstMatch.screenshot()
        XCTAssertNoThrow(try screenshot.pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("manual-\(language)-\(name).png")))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "manual-\(language)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
