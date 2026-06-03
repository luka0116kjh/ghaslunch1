import SwiftUI
import UIKit

@main
struct GHASLunchApp: App {
    @AppStorage("theme") private var themePreference = ""

    init() {
        let startupTheme = UserDefaults.standard.string(forKey: "theme") ?? ""
        let startupPrefersDark = startupTheme == "dark" ||
            (startupTheme != "light" && UITraitCollection.current.userInterfaceStyle == .dark)
        let startupBackground = startupPrefersDark
            ? UIColor(hex: 0x121212)
            : UIColor(hex: 0xF6F6F6)
        UIWindow.appearance().backgroundColor = startupBackground
        // Order matters: legacy copy first, then collapse the old master gate into categories.
        NativeNotificationSettings.prepareLegacyMigrationIfNeeded()
        NativeNotificationSettings.migrateMasterGateIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
                .task {
                    await NativeNotificationService.reconcileLegacyMigrationIfNeeded()
                }
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
