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
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Enable shake-to-open traffic inspector
                // Shake your device to open the inspector sheet!
                .netChecker()
        }
    }
}
