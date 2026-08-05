//
//  FlowsUITests.swift
//  CheckerTestAppUITests
//
//  Экраны сценариев. Демо-приложение показывает их отдельной вкладкой,
//  чтобы тесты добирались до них без shake-жеста.
//

import XCTest

final class FlowsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Сценарии сохраняются между запусками, поэтому без сброса каждый тест
        // видел бы данные предыдущего
        app.launchArguments += ["-NetCheckerResetState"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Подготовка

    private func makeTraffic() {
        app.tabBars.buttons["API Test"].tap()

        let button = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Single Post"))
            .firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Экран API Test не открылся")

        for _ in 0..<2 { button.tap() }
    }

    private func createFlow(named name: String) {
        app.tabBars.buttons["Flows"].tap()
        XCTAssertTrue(app.navigationBars["Flows"].waitForExistence(timeout: 5), "Вкладка Flows не открылась")

        let add = app.buttons["netchecker.addFlow"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Кнопка создания отсутствует")
        add.tap()

        let field = app.textFields.element(boundBy: 0)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Поле имени сценария не появилось")
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5), "Клавиатура не появилась")
        field.typeText(name)

        let create = app.buttons["Создать"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()

        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: 5),
            "Сценарий «\(name)» не появился в списке"
        )
    }

    // MARK: - Список

    func testEmptyStateExplainsWhatFlowsAreFor() {
        app.tabBars.buttons["Flows"].tap()

        XCTAssertTrue(
            app.staticTexts["Нет сценариев"].waitForExistence(timeout: 5),
            "Пустое состояние не показано"
        )
    }

    func testCreatingFlowAddsItToTheList() {
        createFlow(named: "Checkout")

        XCTAssertTrue(
            app.staticTexts["Checkout"].waitForExistence(timeout: 5),
            "Созданный сценарий не появился в списке"
        )
    }

    // MARK: - Полотно

    func testOpeningFlowShowsRunControl() {
        createFlow(named: "Checkout")
        app.staticTexts["Checkout"].tap()

        XCTAssertTrue(
            app.buttons["Запустить"].waitForExistence(timeout: 5),
            "Кнопка запуска отсутствует"
        )
    }

    /// Пустой сценарий запускать нечем — кнопка должна быть недоступна
    func testRunIsDisabledForEmptyFlow() {
        createFlow(named: "Empty")
        app.staticTexts["Empty"].tap()

        let run = app.buttons["Запустить"]
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        XCTAssertFalse(run.isEnabled, "Пустой сценарий не должен запускаться")
    }

    func testEmptyFlowExplainsHowToAddSteps() {
        createFlow(named: "Empty")
        app.staticTexts["Empty"].tap()

        XCTAssertTrue(
            app.staticTexts["В сценарии нет шагов"].waitForExistence(timeout: 5),
            "Пустое состояние полотна не показано"
        )
    }

    // MARK: - Добавление шагов

    // MARK: - Редактор шага

    /// Из интерфейса должны настраиваться зависимости и передача значений,
    /// иначе параллель и развилки задаются только кодом
    func testStepEditorIsReachableAndShowsDependencies() {
        makeTraffic()
        createFlow(named: "Checkout")
        app.staticTexts["Checkout"].tap()

        app.buttons["Добавить шаги"].tap()
        let firstRow = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        firstRow.tap()
        app.cells.element(boundBy: 1).tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Добавить (")).firstMatch.tap()

        // Открываем второй шаг — у него есть предшественник
        let secondNode = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "/posts")
        ).element(boundBy: 1)
        XCTAssertTrue(secondNode.waitForExistence(timeout: 5))
        secondNode.tap()

        let configure = app.buttons["Настроить шаг"]
        XCTAssertTrue(configure.waitForExistence(timeout: 5), "Переход в редактор шага отсутствует")
        configure.tap()

        XCTAssertTrue(
            app.staticTexts["Ждать завершения"].waitForExistence(timeout: 5),
            "Раздел зависимостей не показан"
        )
        XCTAssertTrue(app.staticTexts["Из ответа"].exists, "Раздел извлечения значений не показан")
        XCTAssertTrue(app.staticTexts["В запрос"].exists, "Раздел подстановки не показан")
    }

    func testStepPickerNumbersSelectionInOrder() {
        makeTraffic()
        createFlow(named: "Checkout")
        app.staticTexts["Checkout"].tap()

        app.buttons["Добавить шаги"].tap()

        let firstRow = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "Список трафика пуст")
        firstRow.tap()

        // Номер вместо галочки — он и задаёт порядок шага
        XCTAssertTrue(
            app.staticTexts["1"].waitForExistence(timeout: 3),
            "Порядковый номер выбора не показан"
        )

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Добавить (")).firstMatch.tap()

        XCTAssertTrue(
            app.buttons["Запустить"].waitForExistence(timeout: 5),
            "После добавления шагов не вернулись на полотно"
        )
    }
}
