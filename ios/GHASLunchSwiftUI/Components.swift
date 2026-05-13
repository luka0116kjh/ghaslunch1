import SwiftUI

struct AppHeader: View {
    let title: String
    let subtitle: String
    let actionIcon: String
    let actionLabel: String
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                BrandMark()

                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: action) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.text(scheme))
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .accessibilityLabel(actionLabel)
            }

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.subText(scheme))
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }
}

struct BrandMark: View {
    var body: some View {
        Image("AppIconSource")
            .resizable()
            .scaledToFill()
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct PillTabBar: View {
    @Binding var selection: HomeTab

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HomeTab.allCases) { tab in
                    Button {
                        selection = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selection == tab ? AppTheme.primaryText : AppTheme.pillText(scheme))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(selection == tab ? AppTheme.primary : AppTheme.pill(scheme))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }
}

struct InfoCard<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.2 : 0.04), radius: scheme == .dark ? 16 : 12, y: 8)
    }
}

struct SectionTitle: View {
    let title: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppTheme.primary)
                .frame(width: 4, height: 18)

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.text(scheme))
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(AppTheme.primary)
            .clipShape(Capsule())
            .shadow(color: AppTheme.primary.opacity(0.2), radius: 12, y: 4)
        }
    }
}
