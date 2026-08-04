//
//  TaggingUITests.swift
//  CheckerTestAppUITests
//
//  Жесты пометки тегами. Всё, что здесь проверяется, уже ломалось хотя бы раз
//  и не было поймано ни сборкой, ни юнит-тестами: это поведение SwiftUI
//  и жизненный цикл, а не логика.
//

import XCTest

final class TaggingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        makeSomeTraffic()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Подготовка

    /// Создать несколько записей, чтобы было что помечать.
    /// Подписи кнопок многострочные, поэтому ищем по вхождению.
    private func makeSomeTraffic() {
        app.tabBars.buttons["API Test"].tap()

        let button = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Single Post"))
            .firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Экран API Test не открылся")

        for _ in 0..<3 {
            button.tap()
        }

        app.tabBars.buttons["Traffic"].tap()
    }

    private func firstRow() -> XCUIElement {
        let row = app.cells.element(boundBy: 0)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Список трафика пуст")
        return row
    }

    private func createTag(named name: String) {
        firstRow().press(forDuration: 1.1)

        let newTag = app.buttons["Новый тег…"]
        XCTAssertTrue(newTag.waitForExistence(timeout: 5), "Меню тегов не открылось")
        newTag.tap()

        // По идентификатору, а не по индексу: под листом есть строка поиска,
        // и запрос по индексу цеплял именно её
        let field = app.textFields["netchecker.tagName"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Поле имени тега не появилось")

        // Между появлением листа и готовностью поля к вводу есть зазор:
        // без ожидания клавиатуры ввод уходит в никуда
        field.tap()
        XCTAssertTrue(
            app.keyboards.element.waitForExistence(timeout: 5),
            "Клавиатура не появилась — поле не получило фокус"
        )
        field.typeText(name)

        app.buttons["Пометить"].tap()
    }

    // MARK: - Долгое нажатие

    func testLongPressOpensTagMenu() {
        firstRow().press(forDuration: 1.1)

        XCTAssertTrue(
            app.buttons["Новый тег…"].waitForExistence(timeout: 5),
            "Долгое нажатие не открыло меню тегов"
        )
    }

    /// Регрессия: чип появлялся только после закрытия и повторного открытия инспектора
    func testCreatingTagMarksTheRequestImmediately() {
        createTag(named: "UITestFlow")

        XCTAssertTrue(
            app.staticTexts["UITestFlow"].waitForExistence(timeout: 5),
            "Тег не появился в списке сразу после пометки"
        )
    }

    /// Регрессия: после долгого нажатия одиночный тап переставал открывать строку
    func testRowStillOpensAfterLongPress() {
        firstRow().press(forDuration: 1.1)

        // Закрыть контекстное меню, ничего не выбирая
        app.tap()
        XCTAssertTrue(app.cells.element(boundBy: 0).waitForExistence(timeout: 5))

        firstRow().tap()

        XCTAssertTrue(
            app.navigationBars["Request Details"].waitForExistence(timeout: 5),
            "После долгого нажатия строка перестала открываться по тапу"
        )
    }

    // MARK: - Фильтр по тегу

    func testTagChipFiltersAndClears() {
        createTag(named: "FilterFlow")

        let countBefore = app.cells.count
        XCTAssertGreaterThan(countBefore, 1, "Для проверки фильтра нужно больше одной записи")

        let chip = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "FilterFlow"))
            .firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Чип тега не появился в полосе фильтра")

        chip.tap()
        XCTAssertLessThan(app.cells.count, countBefore, "Фильтр по тегу не сузил список")

        chip.tap()
        XCTAssertEqual(app.cells.count, countBefore, "Повторный тап не снял фильтр")
    }

    // MARK: - Множественный выбор

    func testSelectionModeTagsSeveralRequests() {
        app.navigationBars["Network Traffic"].buttons["More"].tap()

        let selectMany = app.buttons["Пометить несколько"]
        XCTAssertTrue(selectMany.waitForExistence(timeout: 5), "Пункт «Пометить несколько» отсутствует")
        selectMany.tap()

        XCTAssertTrue(
            app.staticTexts["Выберите запросы"].waitForExistence(timeout: 5),
            "Панель выбора не появилась"
        )

        app.cells.element(boundBy: 0).tap()
        app.cells.element(boundBy: 1).tap()

        XCTAssertTrue(
            app.staticTexts["Выбрано: 2"].waitForExistence(timeout: 3),
            "Счётчик выбранных не обновился"
        )

        app.buttons["Готово"].tap()
        XCTAssertFalse(app.staticTexts["Выбрано: 2"].exists, "Режим выбора не завершился")
    }

    /// В режиме выбора строка не должна открываться — тап отмечает её
    func testSelectionModeDoesNotOpenDetail() {
        app.navigationBars["Network Traffic"].buttons["More"].tap()
        app.buttons["Пометить несколько"].tap()
        XCTAssertTrue(app.staticTexts["Выберите запросы"].waitForExistence(timeout: 5))

        app.cells.element(boundBy: 0).tap()

        XCTAssertFalse(
            app.navigationBars["Request Details"].exists,
            "В режиме выбора тап открыл экран запроса вместо отметки"
        )
        XCTAssertTrue(app.staticTexts["Выбрано: 1"].waitForExistence(timeout: 3))
    }
}
