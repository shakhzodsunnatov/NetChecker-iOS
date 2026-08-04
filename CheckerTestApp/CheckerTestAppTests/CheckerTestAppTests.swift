//
//  CheckerTestAppTests.swift
//  CheckerTestAppTests
//
//  Created by Shakhzod on 04/02/26.
//

import Testing
import Foundation
@testable import CheckerTestApp
import NetCheckerTraffic

/// Проверка того, что приложение собрано против NetChecker 2.0.0, а не более старой версии.
///
/// Локальная ссылка на пакет молчалива: если рабочее дерево SDK окажется на
/// другой ветке или ссылку вернут на опубликованную 1.x, приложение соберётся
/// без единого предупреждения — просто с другим кодом. Эти тесты обращаются
/// к API, которого до 2.0.0 не существовало, и падают на этапе компиляции,
/// если версия не та.
struct NetCheckerIntegrationTests {

    @Test("Условия сети доступны — появились в 2.0.0")
    func networkConditionsExist() {
        #expect(NetworkConditionProfile.threeG.latency > 0)
        #expect(NetworkConditionProfile.offline.isOffline)
        #expect(NetworkConditionProfile.none.isTransparent)
        #expect(NetworkConditionProfile.builtIn.count >= 5)
    }

    @Test("Импорт HAR доступен — появился в 2.0.0")
    func harImportExists() throws {
        let har = Data("""
        {"log":{"version":"1.2","creator":{"name":"t","version":"1"},"entries":[
          {"request":{"method":"GET","url":"https://api.example.com/ping"},
           "response":{"status":200}}
        ]}}
        """.utf8)

        let records = try HARParser.parse(har)
        #expect(records.count == 1)
        #expect(records.first?.response?.statusCode == 200)
    }

    @Test("Политика захвата применяется — до 2.0.0 настройки не работали")
    func capturePolicyIsEnforced() {
        var config = InterceptorConfiguration()
        config.maxBodySizeToCapture = 100

        #expect(config.bodyWithinLimits(Data(repeating: 0, count: 101)) == nil)
        #expect(config.bodyWithinLimits(Data(repeating: 0, count: 100)) != nil)
    }

    @Test("Токены не маскируются при захвате по умолчанию")
    func tokensSurviveCaptureByDefault() {
        let config = InterceptorConfiguration()
        let headers = config.redacted(headers: ["Authorization": "Bearer t"])

        #expect(headers["Authorization"] == "Bearer t")
    }

    @Test("Настройка retentionPeriod существует — до 2.0.0 она игнорировалась")
    func retentionPeriodExists() {
        var config = InterceptorConfiguration()
        config.retentionPeriod = 600

        #expect(config.retentionPeriod == 600)
    }
}
