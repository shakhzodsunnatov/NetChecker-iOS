//
//  CheckerTestAppApp.swift
//  CheckerTestApp
//
//  Created by Shakhzod on 04/02/26.
//

import SwiftUI
import NetCheckerTraffic

@main
struct CheckerTestAppApp: App {

    init() {
        Self.resetStateIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Enable shake-to-open traffic inspector
                // Shake your device to open the inspector sheet!
                .netChecker()
        }
    }

    /// Сброс сохранённого состояния SDK перед UI-тестом.
    ///
    /// Сценарии, теги и правила живут в UserDefaults и переживают запуск,
    /// поэтому без сброса тесты видят данные, оставленные предыдущим тестом,
    /// и проверка пустого состояния не проходит.
    private static func resetStateIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-NetCheckerResetState") else { return }

        for key in [
            "NetCheckerFlows",
            "NetCheckerTagRules",
            "NetCheckerCustomTags",
            "NetCheckerTaggedRequests",
            "NetCheckerMockRules",
            "NetCheckerHiddenFeatures",
            "NetCheckerConditionsEnabled",
            "NetCheckerConditionsActiveProfile"
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
