//
//  FlowLiveRunUITests.swift
//  CheckerTestAppUITests
//
//  Прогон сценария против настоящего API.
//
//  Остальные тесты движка используют подставной исполнитель — это правильно
//  для проверки семантики графа, но реальной сети он не видит. Здесь запрос
//  уходит на jsonplaceholder.typicode.com, поэтому тест зависит от сети
//  и не годится для запуска без интернета.
//

import XCTest

final class FlowLiveRunUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-NetCheckerResetState"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func seedDemoFlowAndOpenIt() {
        app.tabBars.buttons["Home"].tap()

        let seed = app.buttons["Demo Flow"]
        XCTAssertTrue(seed.waitForExistence(timeout: 10), "Кнопка создания демо-сценария отсутствует")
        seed.tap()

        app.tabBars.buttons["Flows"].tap()

        let flow = app.staticTexts["JSONPlaceholder Demo"]
        XCTAssertTrue(flow.waitForExistence(timeout: 5), "Демо-сценарий не появился")
        flow.tap()
    }

    /// Сценарий целиком: значение из ответа первого шага подставляется
    /// в путь третьего, параллельный триггер не задерживает прогон
    func testFlowRunsAgainstLiveAPI() {
        seedDemoFlowAndOpenIt()

        let run = app.buttons["Запустить"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.tap()

        // Успешный шаг показывает код ответа и длительность
        let succeeded = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "200")
        ).firstMatch

        XCTAssertTrue(
            succeeded.waitForExistence(timeout: 45),
            "Ни один шаг не завершился успешно — сценарий не отработал против живого API"
        )
    }

    /// Доказательство передачи значения: третий шаг должен показать,
    /// что в путь подставился userId, полученный из первого ответа
    func testSubstitutedValueIsVisibleAfterRun() {
        seedDemoFlowAndOpenIt()

        app.buttons["Запустить"].tap()

        let succeeded = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "200")
        ).firstMatch
        XCTAssertTrue(succeeded.waitForExistence(timeout: 45), "Прогон не завершился")

        // Шаг с подстановкой
        let node = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "/users/")
        ).firstMatch
        XCTAssertTrue(node.waitForExistence(timeout: 10), "Шаг с подстановкой не найден")
        node.tap()

        XCTAssertTrue(
            app.staticTexts["Подставлено"].waitForExistence(timeout: 10),
            "Раздел подстановок отсутствует — значение не передалось"
        )
        XCTAssertTrue(
            app.staticTexts["userId"].exists,
            "Имя переданного значения не показано"
        )
    }
}
