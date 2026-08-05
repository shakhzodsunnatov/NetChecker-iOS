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

    // MARK: - Блоки

    /// Демо-сценарий даёт три шага без обращения к сети
    private func openDemoFlow() {
        app.tabBars.buttons["Home"].tap()
        let seed = app.buttons["Demo Flow"]
        XCTAssertTrue(seed.waitForExistence(timeout: 10), "Кнопка демо-сценария отсутствует")
        seed.tap()

        app.tabBars.buttons["Flows"].tap()
        let flow = app.staticTexts["JSONPlaceholder Demo"]
        XCTAssertTrue(flow.waitForExistence(timeout: 5))
        flow.tap()
        XCTAssertTrue(app.buttons["Запустить"].waitForExistence(timeout: 5))
    }

    private func selectSteps(_ paths: [String]) {
        app.buttons["netchecker.flowMenu"].tap()
        app.buttons["Выбрать шаги"].tap()

        for path in paths {
            let node = app.staticTexts[path]
            XCTAssertTrue(node.waitForExistence(timeout: 5), "Шаг \(path) не найден")
            node.tap()
        }
    }

    /// Ради этого блок и нужен: сложить шаги в контейнер,
    /// а не вычищать зависимости по одной
    func testSelectedStepsBecomeAParallelBlock() {
        openDemoFlow()
        selectSteps(["/posts/1", "/todos/1"])

        XCTAssertTrue(app.staticTexts["Выбрано 2"].waitForExistence(timeout: 3), "Счётчик выбора не показан")

        app.buttons["netchecker.groupSelection"].tap()
        app.buttons["Одновременно"].firstMatch.tap()

        let create = app.buttons["Создать"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "Диалог названия блока не открылся")
        create.tap()

        XCTAssertTrue(
            app.staticTexts["одновременно"].waitForExistence(timeout: 5),
            "Рамка блока на полотне не появилась"
        )
    }

    func testBlockCanBeSwitchedToSequence() {
        openDemoFlow()
        selectSteps(["/posts/1", "/todos/1"])

        app.buttons["netchecker.groupSelection"].tap()
        app.buttons["Одновременно"].firstMatch.tap()
        app.buttons["Создать"].tap()

        let header = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "netchecker.flowGroup")
        ).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Заголовок блока не найден")
        header.tap()

        XCTAssertTrue(app.staticTexts["Как выполняется"].waitForExistence(timeout: 5), "Редактор блока не открылся")
        app.buttons["По очереди"].tap()
        app.buttons["Готово"].tap()

        XCTAssertTrue(
            app.staticTexts["по очереди"].waitForExistence(timeout: 5),
            "Режим блока не сменился на полотне"
        )
    }

    /// Пакетное удаление: по одному шагу это слишком долго
    func testSelectedStepsAreDeletedTogether() {
        openDemoFlow()
        selectSteps(["/posts/1", "/todos/1"])

        app.buttons["netchecker.deleteSelection"].tap()

        XCTAssertTrue(
            app.staticTexts["/users/{userId}"].waitForExistence(timeout: 5),
            "Оставшийся шаг пропал"
        )
        XCTAssertFalse(app.staticTexts["/todos/1"].exists, "Удалённый шаг остался на полотне")
    }

    func testFullScreenHidesTheRunBarAndTabs() {
        openDemoFlow()

        app.buttons["netchecker.flowFullScreen"].tap()

        XCTAssertFalse(
            app.tabBars.buttons["Flows"].waitForExistence(timeout: 2),
            "Панель вкладок осталась в полноэкранном режиме"
        )
        XCTAssertTrue(app.buttons["Запустить"].exists, "Запуск должен остаться доступным")
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
