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

    /// Главный способ связать шаги — протянуть провод от кружка под шагом
    /// к другому шагу. Экран связывания должен открыться на нужной паре
    /// и показать настоящие поля ответа
    func testDraggingWireOpensConnectScreenForThatPair() {
        seedDemoFlowAndOpenIt()

        app.buttons["Запустить"].tap()
        let succeeded = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "200")
        ).firstMatch
        XCTAssertTrue(succeeded.waitForExistence(timeout: 45), "Прогон не завершился")

        let outlet = app.descendants(matching: .any)["netchecker.flowOutlet.2"]
        XCTAssertTrue(outlet.waitForExistence(timeout: 10), "Кружок связи у второго шага отсутствует")

        let target = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "/users/")
        ).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))

        outlet.press(forDuration: 0.15, thenDragTo: target)

        XCTAssertTrue(
            app.staticTexts["Нажмите значение из ответа"].waitForExistence(timeout: 10),
            "Экран связывания не открылся после броска провода"
        )
        // Поля берутся из настоящего ответа второго шага, а не вводятся руками
        XCTAssertTrue(app.staticTexts["completed"].exists, "Поля ответа не показаны")
    }

    /// Связь создаётся двумя нажатиями и сразу становится видимой
    func testConnectingValueCreatesLinkInOneAction() {
        seedDemoFlowAndOpenIt()

        app.buttons["Запустить"].tap()
        let succeeded = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "200")
        ).firstMatch
        XCTAssertTrue(succeeded.waitForExistence(timeout: 45), "Прогон не завершился")

        let outlet = app.descendants(matching: .any)["netchecker.flowOutlet.2"]
        XCTAssertTrue(outlet.waitForExistence(timeout: 10))

        let target = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "/users/")
        ).firstMatch
        outlet.press(forDuration: 0.15, thenDragTo: target)

        XCTAssertTrue(app.staticTexts["title"].waitForExistence(timeout: 10), "Поле ответа не найдено")
        app.staticTexts["title"].tap()

        XCTAssertTrue(
            app.staticTexts["Теперь выберите, куда его положить"].waitForExistence(timeout: 5),
            "Подсказка не сменилась после выбора значения"
        )

        app.staticTexts["новый заголовок"].firstMatch.tap()

        XCTAssertTrue(
            app.staticTexts["УЖЕ СВЯЗАНО"].waitForExistence(timeout: 5),
            "Созданная связь не показана"
        )
    }
}
