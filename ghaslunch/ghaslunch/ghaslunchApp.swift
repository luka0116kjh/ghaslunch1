//
//  ghaslunchApp.swift
//  ghaslunch
//
//  Created by luka on 5/15/26.
//

import FirebaseCore
import SwiftUI

@main
struct ghaslunchApp: App {
    @AppStorage("theme") private var themePreference = ""

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch themePreference {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}
