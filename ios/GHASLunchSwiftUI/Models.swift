import Foundation

struct MealCardData: Identifiable {
    let id = UUID()
    let title: String
    let menu: String
    let calories: String
}

struct WeeklyMealData: Identifiable {
    let id = UUID()
    let date: String
    let menu: String
}

struct TimetableRowData: Identifiable {
    let id = UUID()
    let period: String
    let subject: String
}

enum HomeTab: String, CaseIterable, Identifiable {
    case today = "오늘"
    case tomorrow = "내일"
    case week = "이번 주"
    case timetable = "시간표"

    var id: String { rawValue }
}

enum ThemePreference: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var next: ThemePreference {
        switch self {
        case .system:
            return .light
        case .light:
            return .dark
        case .dark:
            return .system
        }
    }
}
