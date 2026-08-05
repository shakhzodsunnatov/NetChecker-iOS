//
//  CheckerTestAppUITests.swift
//  CheckerTestAppUITests
//
//  Created by Shakhzod on 04/02/26.
//

import XCTest

final class CheckerTestAppUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Вкладки

    func testAllTabsAreReachable() {
        for tab in ["Home", "API Test", "Traffic", "Flows", "Rules"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Вкладка \(tab) отсутствует")
            button.tap()
        }
    }

    /// Регрессия: экран трафика не создаёт собственный NavigationStack начиная с 2.0.0.
    /// Без обёртки в приложении пропадали заголовок и вся панель инструментов.
    func testTrafficScreenShowsItsNavigationBar() {
        app.tabBars.buttons["Traffic"].tap()

        XCTAssertTrue(
            app.navigationBars["Network Traffic"].waitForExistence(timeout: 5),
            "Заголовок экрана трафика не отображается — потерян NavigationStack"
        )
    }

    /// Регрессия: два ToolbarItem с одинаковым placement схлопывались,
    /// из-за чего правые кнопки пропадали или не реагировали.
    func testTrafficToolbarActionsArePresentAndOpen() {
        app.tabBars.buttons["Traffic"].tap()

        let bar = app.navigationBars["Network Traffic"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))

        let menu = bar.buttons.element(boundBy: bar.buttons.count - 1)
        XCTAssertTrue(menu.exists, "Кнопка меню действий отсутствует в панели")

        menu.tap()

        // Меню должно реально раскрыться, а не просто существовать
        XCTAssertTrue(
            app.buttons["Import HAR"].waitForExistence(timeout: 5),
            "Меню действий не раскрылось"
        )
        XCTAssertTrue(app.buttons["Export HAR"].exists)
        XCTAssertTrue(app.buttons["Statistics"].exists)
    }

    // MARK: - Условия сети

    /// Троттлинг включается с главного экрана и отражается в баннере
    func testThrottleQuickActionTogglesNetworkCondition() {
        app.tabBars.buttons["Home"].tap()

        let throttle = app.buttons["Throttle 3G"]
        XCTAssertTrue(throttle.waitForExistence(timeout: 5), "Кнопка троттлинга отсутствует")
        throttle.tap()

        XCTAssertTrue(
            app.staticTexts["Network: 3G"].waitForExistence(timeout: 5),
            "Баннер активного профиля сети не появился"
        )

        app.buttons["Off"].tap()
        XCTAssertFalse(app.staticTexts["Network: 3G"].waitForExistence(timeout: 2))
    }

    // MARK: - Запуск

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
