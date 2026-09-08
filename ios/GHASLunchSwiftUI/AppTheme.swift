import SwiftUI
import UIKit

enum AppTheme {
    static let primary = Color(hex: 0x2563EB)
    static let primaryText = Color.white
    static let lightBackground = Color(hex: 0xF6F6F6)
    static let darkBackground = Color(hex: 0x121212)
    static let lightCard = Color.white
    static let darkCard = Color(hex: 0x1E1E1E)
    static let lightText = Color(hex: 0x191919)
    static let darkText = Color.white
    static let lightSubText = Color(hex: 0x707070)
    static let darkSubText = Color(hex: 0xAAAAAA)
    static let lightBorder = Color(hex: 0xF2F2F2)
    static let darkBorder = Color(hex: 0x2C2C2C)
    static let lightPill = Color(hex: 0xEEEEEE)
    static let darkPill = Color(hex: 0x2C2C2C)
    static let lightPillText = Color(hex: 0x8E8E8E)
    static let darkPillText = Color(hex: 0x707070)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBackground : lightBackground
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkCard : lightCard
    }

    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkText : lightText
    }

    static func subText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSubText : lightSubText
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBorder : lightBorder
    }

    static func pill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkPill : lightPill
    }

    static func pillText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? darkPillText : lightPillText
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
