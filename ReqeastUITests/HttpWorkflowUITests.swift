import XCTest

final class HttpWorkflowUITests: XCTestCase {
    func testWorkflowAndIllustratedGuideAreReachable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotMode", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        UITestHelpers.activateAndWaitForWindow(app)
        UITestHelpers.waitForDemoData(in: app)
        let project = UITestHelpers.projectRow(named: "Weather API", in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        UITestHelpers.press(project)
        Thread.sleep(forTimeInterval: 0.5)
        let request = UITestHelpers.requestRow(named: "GET Current Weather", in: app)
        XCTAssertTrue(request.waitForExistence(timeout: 5))
        #if os(macOS)
        request.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        #else
        UITestHelpers.press(request)
        #endif
        Thread.sleep(forTimeInterval: 0.5)
        let workflow = app.buttons["http-workflow-button"].firstMatch
        XCTAssertTrue(workflow.waitForExistence(timeout: 5))
        UITestHelpers.press(workflow)
        let guide = app.buttons["workflow-guide"].firstMatch
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        UITestHelpers.press(guide)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", "Getting Started", "Getting Started"
        )).firstMatch.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "HTTP workflow illustrated guide"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
