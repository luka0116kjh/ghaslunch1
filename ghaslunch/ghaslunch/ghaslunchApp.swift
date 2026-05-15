//
//  ghaslunchApp.swift
//  ghaslunch
//
//  Created by luka on 5/15/26.
//

import SwiftUI

@main
struct ghaslunchApp: App {
    @AppStorage("theme") private var themePreference = ""

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
