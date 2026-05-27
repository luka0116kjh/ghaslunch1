import SwiftUI

@main
struct GHASLunchApp: App {
    @AppStorage("theme") private var themePreference = ""

    init() {
        NativeNotificationSettings.prepareLegacyMigrationIfNeeded()
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
