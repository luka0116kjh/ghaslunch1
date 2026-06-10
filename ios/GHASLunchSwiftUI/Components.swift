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
    @State private var timeEditor: TimeEditor?
    @State private var editorHour = ""
    @State private var editorMinute = ""
    @State private var editorPeriod: DayPeriod = .morning
    @State private var timeValidationMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("필요한 알림만 선택해 받을 수 있습니다.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.subText(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    bulkActionButtons

                    settingCard {
                        categoryRow(
                            title: "급식 알림",
                            enabled: binding(\.mealEnabled),
                            timeTitle: "급식 알림 시간",
                            time: settings.mealTime,
                            keyPath: \.mealTime
                        )
                        categoryRow(
                            title: "시간표 알림",
                            enabled: binding(\.timetableEnabled),
                            timeTitle: "시간표 알림 시간",
                            time: settings.timetableTime,
                            keyPath: \.timetableTime
                        )
                        categoryRow(
                            title: "학교 공지 알림",
                            enabled: binding(\.schoolNoticeEnabled),
                            timeTitle: "학교 공지 알림 시간",
                            time: settings.schoolNoticeTime,
                            keyPath: \.schoolNoticeTime
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
                        saveAndClose()
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                }
            }
        }
        .overlay {
            if let timeEditor {
                timeInputDialog(timeEditor)
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
        timeTitle: String,
        time: Date,
        keyPath: WritableKeyPath<NativeNotificationSettings, Date>
    ) -> some View {
        VStack(spacing: 8) {
            themedToggle(title, isOn: enabled)
            Button {
                beginEditingTime(keyPath: keyPath)
            } label: {
                Text("\(timeTitle): \(formattedTime(time))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.text(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.pill(scheme))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.border(scheme), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            // Time editing stays available even when the category toggle is OFF; the time is just saved.
        }
        .padding(.vertical, 3)
    }

    // Single master toggle (not a separate gate): label and action follow the current aggregate
    // state. ON (any category enabled) -> "모든 알림 끄기"; OFF -> "모든 알림 켜기". It flips every
    // category at once and immediately persists + reconciles. Saved times are left untouched.
    private var bulkActionButtons: some View {
        let isOn = settings.enabled
        return bulkButton(
            title: isOn ? "모든 알림 끄기" : "모든 알림 켜기",
            systemImage: isOn ? "bell.slash.fill" : "bell.fill",
            filled: !isOn
        ) {
            applyAllCategories(enabled: !isOn)
        }
    }

    private func bulkButton(
        title: String,
        systemImage: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(filled ? Color.white : AppTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(filled ? AppTheme.primary : AppTheme.pill(scheme))
            .overlay {
                if !filled {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.border(scheme), lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func applyAllCategories(enabled: Bool) {
        settings.setAllCategories(enabled: enabled)
        settings.save()
        Task {
            let allowed = await NativeNotificationService.applySavedSettings()
            await MainActor.run {
                if enabled && !allowed && settings.enabled {
                    // Categories turned on but OS permission is missing: keep choices, report OFF.
                    permissionDenied = true
                    postNotificationState(false)
                } else {
                    postNotificationState(enabled ? (allowed && settings.enabled) : false)
                }
            }
        }
    }

    private func themedToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(AppTheme.primary)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.text(scheme))
    }

    private func binding(_ keyPath: WritableKeyPath<NativeNotificationSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { value in
                settings[keyPath: keyPath] = value
            }
        )
    }

    private func beginEditingTime(keyPath: WritableKeyPath<NativeNotificationSettings, Date>) {
        let time = settings[keyPath: keyPath]
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 0
        editorHour = String(hour % 12 == 0 ? 12 : hour % 12)
        editorMinute = String(format: "%02d", components.minute ?? 0)
        editorPeriod = hour < 12 ? .morning : .afternoon
        timeValidationMessage = nil
        timeEditor = TimeEditor(keyPath: keyPath)
    }

    private func formattedTime(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? DayPeriod.morning.rawValue : DayPeriod.afternoon.rawValue
        return String(format: "%@ %d:%02d", period, displayHour, components.minute ?? 0)
    }

    private func confirmTime(_ editor: TimeEditor) {
        let hourText = editorHour.trimmingCharacters(in: .whitespacesAndNewlines)
        let minuteText = editorMinute.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hourText.isEmpty, !minuteText.isEmpty else {
            timeValidationMessage = "시간과 분을 입력해 주세요."
            return
        }

        guard
            let hour = Int(hourText), (1...12).contains(hour),
            let minute = Int(minuteText), (0...59).contains(minute)
        else {
            timeValidationMessage = "시간은 1~12, 분은 0~59 사이여야 합니다."
            return
        }

        let hour24 = editorPeriod == .morning ? hour % 12 : (hour % 12) + 12
        let oldValue = settings[keyPath: editor.keyPath]
        settings[keyPath: editor.keyPath] = Calendar.current.date(
            bySettingHour: hour24,
            minute: minute,
            second: 0,
            of: oldValue
        ) ?? oldValue
        timeEditor = nil
        timeValidationMessage = nil
    }

    private func limitedNumericBinding(_ value: Binding<String>) -> Binding<String> {
        Binding {
            value.wrappedValue
        } set: { updatedValue in
            value.wrappedValue = String(updatedValue.filter(\.isNumber).prefix(2))
        }
    }

    private func timeInputDialog(_ editor: TimeEditor) -> some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("알림 시간 설정")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.text(scheme))

                HStack(spacing: 12) {
                    timeInput(title: "시간", text: $editorHour)

                    Text(":")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(AppTheme.text(scheme))
                        .padding(.top, 22)

                    timeInput(title: "분", text: $editorMinute)
                }

                Picker("오전 오후", selection: $editorPeriod) {
                    ForEach(DayPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.primary)

                if let timeValidationMessage {
                    Text(timeValidationMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button("취소") {
                        timeEditor = nil
                        timeValidationMessage = nil
                    }
                    .foregroundStyle(AppTheme.primary)

                    Button("확인") {
                        confirmTime(editor)
                    }
                    .foregroundStyle(AppTheme.primary)
                    .fontWeight(.semibold)
                    .padding(.leading, 14)
                }
            }
            .padding(22)
            .background(AppTheme.card(scheme))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.border(scheme), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.3 : 0.15), radius: 18, y: 8)
            .padding(.horizontal, 28)
        }
    }

    private func timeInput(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.subText(scheme))

            TextField(title == "시간" ? "07" : "30", text: limitedNumericBinding(text))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.text(scheme))
                .padding(.vertical, 10)
                .background(AppTheme.pill(scheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.border(scheme), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func saveAndClose() {
        settings.save()
        Task {
            let allowed = await NativeNotificationService.applySavedSettings()
            await MainActor.run {
                if !allowed && settings.enabled {
                    // Categories are on but OS permission is missing: keep the user's choices,
                    // report the aggregate as off (nothing can be delivered) and explain.
                    postNotificationState(false)
                    permissionDenied = true
                } else {
                    postNotificationState(settings.enabled)
                    dismiss()
                }
            }
        }
    }

    private func postNotificationState(_ enabled: Bool) {
        NotificationCenter.default.post(
            name: .nativeNotificationSettingsDidChange,
            object: nil,
            userInfo: ["enabled": enabled]
        )
    }

    private enum DayPeriod: String, CaseIterable {
        case morning = "오전"
        case afternoon = "오후"
    }

    private struct TimeEditor {
        let keyPath: WritableKeyPath<NativeNotificationSettings, Date>
    }
}
