import SwiftUI

struct AppHeader: View {
    let title: String
    let subtitle: String
    let secondaryTitle: String?
    let secondaryActionLabel: String?
    let secondaryAction: (() -> Void)?
    let actionIcon: String
    let actionLabel: String
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    init(
        title: String,
        subtitle: String,
        secondaryTitle: String? = nil,
        secondaryActionLabel: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        actionIcon: String,
        actionLabel: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.secondaryTitle = secondaryTitle
        self.secondaryActionLabel = secondaryActionLabel
        self.secondaryAction = secondaryAction
        self.actionIcon = actionIcon
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                BrandMark()

                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.text(scheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let secondaryTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(AppTheme.text(scheme))
                            .frame(width: 38, height: 38)
                            .background(AppTheme.pill(scheme))
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel(secondaryActionLabel ?? secondaryTitle)
                }

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
        .shadow(color: Color.black.opacity(scheme == .dark ? 0.2 : 0.04), radius: scheme == .dark ? 32 : 12, y: 8)
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

struct SwitchPillButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(AppTheme.text(scheme))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.pill(scheme))
                .clipShape(Capsule())
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

struct NotificationSettingsCardButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)

                Text("알림 설정")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.text(scheme))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(AppTheme.card(scheme))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.border(scheme), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(
                color: Color.black.opacity(scheme == .dark ? 0.22 : 0.08),
                radius: 12,
                y: 5
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("알림 설정")
    }
}

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var settings = NativeNotificationSettings.load()
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    settingCard {
                        themedToggle("전체 알림", isOn: binding(\.enabled))
                    }

                    settingCard {
                        categoryRow(
                            title: "급식 알림",
                            enabled: binding(\.mealEnabled),
                            time: timeBinding(\.mealTime)
                        )
                        Divider().overlay(AppTheme.border(scheme))
                        categoryRow(
                            title: "시간표 알림",
                            enabled: binding(\.timetableEnabled),
                            time: timeBinding(\.timetableTime)
                        )
                        Divider().overlay(AppTheme.border(scheme))
                        categoryRow(
                            title: "학교 공지 알림",
                            enabled: binding(\.schoolNoticeEnabled),
                            time: timeBinding(\.schoolNoticeTime)
                        )
                    }
                }
                .padding(18)
            }
            .background(AppTheme.background(scheme).ignoresSafeArea())
            .navigationTitle("알림 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        persistAndSchedule()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("알림 권한이 필요합니다", isPresented: $permissionDenied) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("설정 앱에서 알림 권한을 허용한 뒤 다시 시도해주세요.")
        }
    }

    @ViewBuilder
    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card(scheme))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border(scheme), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func categoryRow(
        title: String,
        enabled: Binding<Bool>,
        time: Binding<Date>
    ) -> some View {
        VStack(spacing: 8) {
            themedToggle(title, isOn: enabled)
            DatePicker(
                "\(title) 시간",
                selection: time,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .tint(AppTheme.primary)
            .foregroundStyle(AppTheme.subText(scheme))
            .disabled(!settings.enabled || !enabled.wrappedValue)
            .opacity(settings.enabled && enabled.wrappedValue ? 1 : 0.45)
        }
        .padding(.vertical, 3)
    }

    private func themedToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(AppTheme.primary)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.text(scheme))
            .disabled(title != "전체 알림" && !settings.enabled)
            .opacity(title == "전체 알림" || settings.enabled ? 1 : 0.45)
    }

    private func binding(_ keyPath: WritableKeyPath<NativeNotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { value in
                settings[keyPath: keyPath] = value
                persistAndSchedule()
            }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<NativeNotificationSettings, Date>) -> Binding<Date> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { value in
                settings[keyPath: keyPath] = value
                persistAndSchedule()
            }
        )
    }

    private func persistAndSchedule() {
        settings.save()
        Task {
            let allowed = await NativeNotificationService.apply(settings)
            if !allowed && settings.enabled {
                await MainActor.run {
                    settings.enabled = false
                    settings.save()
                    permissionDenied = true
                }
            }
        }
    }
}
