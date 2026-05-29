import SwiftUI
import UIKit
import UserNotifications
import WebKit

struct ContentView: View {
    @AppStorage("theme") private var savedTheme = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var isNotificationSettingsPresented = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                GHASLunchWebView()
            }

            NativeNotificationToolbar(isDarkTheme: isDarkTheme) {
                isNotificationSettingsPresented = true
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $isNotificationSettingsPresented) {
            NotificationSettingsView()
        }
    }

    private var backgroundColor: Color {
        isDarkTheme ? Color(hex: 0x121212) : Color(hex: 0xF6F6F6)
    }

    private var isDarkTheme: Bool {
        switch savedTheme {
        case "dark":
            return true
        case "light":
            return false
        default:
            return colorScheme == .dark
        }
    }
}

private struct NativeNotificationToolbar: View {
    let isDarkTheme: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(toolbarTextColor)
                    .frame(width: 44, height: 44)
                    .background(toolbarButtonColor, in: Circle())
            }
            .accessibilityLabel("알림 설정 열기")
            .padding(.trailing, 16)
        }
        .frame(height: 56)
        .background(toolbarColor)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(isDarkTheme ? 0.25 : 0.06))
                .frame(height: 1)
        }
    }

    private var toolbarColor: Color {
        isDarkTheme ? Color(hex: 0x121212) : .white
    }

    private var toolbarButtonColor: Color {
        isDarkTheme ? Color(hex: 0x242424) : Color(hex: 0xF5F5F5)
    }

    private var toolbarTextColor: Color {
        isDarkTheme ? .white : Color(hex: 0x2D2D2D)
    }
}

private struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled: Bool
    @State private var mealEnabled: Bool
    @State private var timetableEnabled: Bool
    @State private var schoolNoticeEnabled: Bool
    @State private var mealTime: Date
    @State private var timetableTime: Date
    @State private var schoolNoticeTime: Date

    init() {
        let defaults = UserDefaults.standard
        _notificationsEnabled = State(initialValue: defaults.bool(forKey: NotificationSettingsKeys.notificationsEnabled))
        _mealEnabled = State(initialValue: defaults.bool(forKey: NotificationSettingsKeys.mealEnabled))
        _timetableEnabled = State(initialValue: defaults.bool(forKey: NotificationSettingsKeys.timetableEnabled))
        _schoolNoticeEnabled = State(initialValue: defaults.bool(forKey: NotificationSettingsKeys.schoolNoticeEnabled))
        _mealTime = State(initialValue: Self.notificationTime(
            defaults: defaults,
            hourKey: NotificationSettingsKeys.mealHour,
            minuteKey: NotificationSettingsKeys.mealMinute,
            defaultHour: 11,
            defaultMinute: 0
        ))
        _timetableTime = State(initialValue: Self.notificationTime(
            defaults: defaults,
            hourKey: NotificationSettingsKeys.timetableHour,
            minuteKey: NotificationSettingsKeys.timetableMinute,
            defaultHour: 7,
            defaultMinute: 30
        ))
        _schoolNoticeTime = State(initialValue: Self.notificationTime(
            defaults: defaults,
            hourKey: NotificationSettingsKeys.schoolNoticeHour,
            minuteKey: NotificationSettingsKeys.schoolNoticeMinute,
            defaultHour: 18,
            defaultMinute: 0
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("알림 사용", isOn: $notificationsEnabled)
                }

                Section("알림 종류") {
                    notificationCategoryRow(
                        title: "급식 알림",
                        enabled: $mealEnabled,
                        time: $mealTime
                    )
                    notificationCategoryRow(
                        title: "시간표 알림",
                        enabled: $timetableEnabled,
                        time: $timetableTime
                    )
                    notificationCategoryRow(
                        title: "학교 공지 알림",
                        enabled: $schoolNoticeEnabled,
                        time: $schoolNoticeTime
                    )
                }
                .disabled(!notificationsEnabled)

                Section {
                    Button(action: save) {
                        Text("저장")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("알림 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(notificationsEnabled, forKey: NotificationSettingsKeys.notificationsEnabled)
        defaults.set(mealEnabled, forKey: NotificationSettingsKeys.mealEnabled)
        defaults.set(timetableEnabled, forKey: NotificationSettingsKeys.timetableEnabled)
        defaults.set(schoolNoticeEnabled, forKey: NotificationSettingsKeys.schoolNoticeEnabled)
        store(time: mealTime, hourKey: NotificationSettingsKeys.mealHour, minuteKey: NotificationSettingsKeys.mealMinute)
        store(time: timetableTime, hourKey: NotificationSettingsKeys.timetableHour, minuteKey: NotificationSettingsKeys.timetableMinute)
        store(time: schoolNoticeTime, hourKey: NotificationSettingsKeys.schoolNoticeHour, minuteKey: NotificationSettingsKeys.schoolNoticeMinute)

        Task {
            await NativeLocalNotificationScheduler.applySavedSettings()
        }

        // TODO(FCM): register the APNs/FCM token and remote category subscriptions
        // only when server-driven push notification delivery is introduced.
        dismiss()
    }

    @ViewBuilder
    private func notificationCategoryRow(
        title: String,
        enabled: Binding<Bool>,
        time: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: enabled)
            DatePicker(
                "\(title) 시간",
                selection: time,
                displayedComponents: .hourAndMinute
            )
            .disabled(!enabled.wrappedValue)
        }
    }

    private func store(time: Date, hourKey: String, minuteKey: String) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        UserDefaults.standard.set(components.hour ?? 0, forKey: hourKey)
        UserDefaults.standard.set(components.minute ?? 0, forKey: minuteKey)
    }

    private static func notificationTime(
        defaults: UserDefaults,
        hourKey: String,
        minuteKey: String,
        defaultHour: Int,
        defaultMinute: Int
    ) -> Date {
        let hour = defaults.object(forKey: hourKey) == nil ? defaultHour : defaults.integer(forKey: hourKey)
        let minute = defaults.object(forKey: minuteKey) == nil ? defaultMinute : defaults.integer(forKey: minuteKey)
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}

private enum NotificationSettingsKeys {
    static let notificationsEnabled = "nativeNotificationsEnabled"
    static let mealEnabled = "nativeNotificationsMeal"
    static let timetableEnabled = "nativeNotificationsTimetable"
    static let schoolNoticeEnabled = "nativeNotificationsSchoolNotice"
    static let mealHour = "nativeNotificationsMealHour"
    static let mealMinute = "nativeNotificationsMealMinute"
    static let timetableHour = "nativeNotificationsTimetableHour"
    static let timetableMinute = "nativeNotificationsTimetableMinute"
    static let schoolNoticeHour = "nativeNotificationsSchoolNoticeHour"
    static let schoolNoticeMinute = "nativeNotificationsSchoolNoticeMinute"
}

private enum NativeLocalNotificationScheduler {
    private struct Category {
        let key: String
        let identifier: String
        let enabledKey: String
        let hourKey: String
        let minuteKey: String
        let defaultHour: Int
        let defaultMinute: Int
        let title: String
        let body: String
        let supportsCachedContent: Bool
    }

    private static let categories = [
        Category(
            key: "meal",
            identifier: "meal_daily_notification",
            enabledKey: NotificationSettingsKeys.mealEnabled,
            hourKey: NotificationSettingsKeys.mealHour,
            minuteKey: NotificationSettingsKeys.mealMinute,
            defaultHour: 11,
            defaultMinute: 0,
            title: "급식 알림",
            body: "오늘 급식을 확인해보세요.",
            supportsCachedContent: true
        ),
        Category(
            key: "timetable",
            identifier: "timetable_daily_notification",
            enabledKey: NotificationSettingsKeys.timetableEnabled,
            hourKey: NotificationSettingsKeys.timetableHour,
            minuteKey: NotificationSettingsKeys.timetableMinute,
            defaultHour: 7,
            defaultMinute: 30,
            title: "시간표 알림",
            body: "오늘 시간표를 확인해보세요.",
            supportsCachedContent: true
        ),
        Category(
            key: "school_notice",
            identifier: "school_notice_daily_notification",
            enabledKey: NotificationSettingsKeys.schoolNoticeEnabled,
            hourKey: NotificationSettingsKeys.schoolNoticeHour,
            minuteKey: NotificationSettingsKeys.schoolNoticeMinute,
            defaultHour: 18,
            defaultMinute: 0,
            title: "학교 공지 알림",
            body: "오늘 학교 공지를 확인해보세요.",
            supportsCachedContent: false
        )
    ]

    static func cacheContent(category: String, date: String, body: String) {
        guard
            let item = categories.first(where: { $0.key == category && $0.supportsCachedContent }),
            date.range(of: #"^\d{8}$"#, options: .regularExpression) != nil
        else {
            return
        }
        let safeBody = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        guard !safeBody.isEmpty else { return }
        UserDefaults.standard.set(date, forKey: cacheDateKey(item))
        UserDefaults.standard.set(safeBody, forKey: cacheBodyKey(item))
    }

    static func applySavedSettings(requestAuthorization: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = categories.map(\.identifier)
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: NotificationSettingsKeys.notificationsEnabled) else {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            return
        }

        let granted: Bool
        if requestAuthorization {
            do {
                granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                granted = false
            }
        } else {
            let settings = await center.notificationSettings()
            granted = settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional ||
                settings.authorizationStatus == .ephemeral
        }
        guard granted else {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            return
        }

        for category in categories {
            center.removePendingNotificationRequests(withIdentifiers: [category.identifier])
            guard defaults.bool(forKey: category.enabledKey) else {
                continue
            }

            let hour = defaults.object(forKey: category.hourKey) == nil
                ? category.defaultHour
                : defaults.integer(forKey: category.hourKey)
            let minute = defaults.object(forKey: category.minuteKey) == nil
                ? category.defaultMinute
                : defaults.integer(forKey: category.minuteKey)
            let content = UNMutableNotificationContent()
            content.title = category.title
            // A repeating local request cannot safely embed content for one specific date.
            // TODO: use daily one-shot rescheduling after app refresh, or Firebase
            // Cloud Functions + FCM scheduled push, for authoritative daily content.
            content.body = category.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: hour, minute: minute),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: category.identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static func cacheDateKey(_ category: Category) -> String {
        "nativeNotificationCached_\(category.key)_date"
    }

    private static func cacheBodyKey(_ category: Category) -> String {
        "nativeNotificationCached_\(category.key)_body"
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

struct GHASLunchWebView: UIViewRepresentable {
    private let appURL = URL(string: "https://ghaslunch1.web.app/?v=20260522-holiday-timetable-fix")!
    private let allowedHost = "ghaslunch1.web.app"
    private let themeKey = "theme"
    private let notificationKey = "noti-enabled"
    private let usesPadLayout = UIDevice.current.userInterfaceIdiom == .pad

    func makeCoordinator() -> Coordinator {
        Coordinator(
            allowedHost: allowedHost,
            themeKey: themeKey,
            notificationKey: notificationKey,
            usesPadLayout: usesPadLayout
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(
            context.coordinator,
            name: Coordinator.messageHandlerName
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: bridgeScript(
                    savedTheme: UserDefaults.standard.string(forKey: themeKey) ?? ""
                ),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: notificationContentCacheScript(),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        if usesPadLayout {
            configuration.userContentController.addUserScript(
                WKUserScript(
                    source: padLayoutScript(),
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
            )
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = webView
        loadFreshAppURL(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        Task { @MainActor in coordinator.disableBarcodeScanMode() }
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: Coordinator.messageHandlerName
        )
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    private func loadFreshAppURL(in webView: WKWebView) {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(
            ofTypes: dataTypes,
            modifiedSince: .distantPast
        ) {
            webView.load(
                URLRequest(
                    url: appURL,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                    timeoutInterval: 30
                )
            )
        }
    }

    private func bridgeScript(savedTheme: String) -> String {
        let escapedTheme = savedTheme
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        return """
        (function() {
            var savedTheme = '\(escapedTheme)';
            var post = function(action, value) {
                try {
                    window.webkit.messageHandlers.\(Coordinator.messageHandlerName).postMessage({
                        action: action,
                        value: value
                    });
                } catch (error) {
                    console.warn('iOS native bridge call failed:', error);
                }
            };
            var bridge = {
                __iosBridge: true,
                // Notifications are temporarily disabled in the web/iOS bridge.
                // They will be reconnected later through native FCM.
                requestNotifications: function() {
                    post('requestNotifications', null);
                },
                cancelNotifications: function() {
                    post('cancelNotifications', null);
                },
                setTheme: function(theme) {
                    savedTheme = theme || '';
                    post('setTheme', savedTheme);
                },
                getTheme: function() {
                    return savedTheme;
                },
                enableBarcodeScanMode: function() {
                    post('enableBarcodeScanMode', null);
                },
                disableBarcodeScanMode: function() {
                    post('disableBarcodeScanMode', null);
                },
                cacheNotificationContent: function(category, date, body) {
                    post('cacheNotificationContent', {
                        category: category,
                        date: date,
                        body: body
                    });
                }
            };
            window.GHASAndroidApp = bridge;
            window.GHASAndroidNotifications = bridge;
        }());
        """
    }

    private func notificationContentCacheScript() -> String {
        """
        (function () {
            var nativeApp = window.GHASAndroidApp;
            if (!nativeApp || typeof nativeApp.cacheNotificationContent !== 'function') return;
            var todayKey = function () {
                var d = new Date();
                return String(d.getFullYear()) +
                    String(d.getMonth() + 1).padStart(2, '0') +
                    String(d.getDate()).padStart(2, '0');
            };
            var compact = function (value) {
                return String(value || '').replace(/\\s+/g, ' ').trim();
            };
            var invalid = function (value) {
                return !value || /불러오는 중|정보가 없습니다|불러오지 못했습니다|주말|휴일/.test(value);
            };
            var flush = function () {
                var mealTitleElement = document.getElementById('meal-view-title');
                var mealTitle = compact(mealTitleElement && mealTitleElement.innerText);
                var lunch = document.getElementById('lunch-menu');
                var lunchText = compact(lunch && lunch.innerText);
                if (mealTitle === '오늘의 급식' && !invalid(lunchText)) {
                    nativeApp.cacheNotificationContent('meal', todayKey(), ('오늘 중식: ' + lunchText).slice(0, 240));
                }

                var titleElement = document.getElementById('timetable-title');
                var title = compact(titleElement && titleElement.innerText);
                var rows = Array.prototype.slice.call(document.querySelectorAll('#timetable-list .timetable-row')).map(function (row) {
                    var periodElement = row.querySelector('.period');
                    var subjectElement = row.querySelector('.subject');
                    var period = compact(periodElement && periodElement.innerText);
                    var subject = compact(subjectElement && subjectElement.innerText);
                    return period && subject && subject !== '공강' ? period + ' ' + subject : '';
                }).filter(Boolean);
                if (title === '오늘 시간표' && rows.length) {
                    nativeApp.cacheNotificationContent('timetable', todayKey(), ('오늘 시간표: ' + rows.join(', ')).slice(0, 240));
                }
            };
            var observer = new MutationObserver(flush);
            observer.observe(document.body, { childList: true, subtree: true, characterData: true });
            window.__ghasNativeContentCollector = { flush: flush, observer: observer };
            flush();
        }());
        """
    }

    private func padLayoutScript() -> String {
        """
        (function() {
            var styleId = 'ghas-ios-pad-layout';
            var css = [
                'html, body { width: 100% !important; }',
                '.container { max-width: none !important; width: 100% !important; padding: 32px max(32px, env(safe-area-inset-left)) 44px max(32px, env(safe-area-inset-right)) !important; }',
                '.header { padding-top: 16px !important; }',
                '.meal-card { padding: 28px !important; }'
            ].join('\\n');
            var apply = function() {
                var existing = document.getElementById(styleId);
                if (!existing) {
                    existing = document.createElement('style');
                    existing.id = styleId;
                    document.head.appendChild(existing);
                }
                existing.textContent = css;
            };
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', apply, { once: true });
            } else {
                apply();
            }
        }());
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let messageHandlerName = "ghasNative"

        private let allowedHost: String
        private let themeKey: String
        private let notificationKey: String
        private let usesPadLayout: Bool
        weak var webView: WKWebView?
        private var originalBrightness: CGFloat?
        private var barcodeScanModeEnabled = false

        init(allowedHost: String, themeKey: String, notificationKey: String, usesPadLayout: Bool) {
            self.allowedHost = allowedHost
            self.themeKey = themeKey
            self.notificationKey = notificationKey
            self.usesPadLayout = usesPadLayout
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillResignActive),
                name: UIApplication.willResignActiveNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.frameInfo.securityOrigin.protocol == "https",
                message.frameInfo.securityOrigin.host == allowedHost,
                let body = message.body as? [String: Any],
                let action = body["action"] as? String
            else {
                return
            }

            switch action {
            case "requestNotifications":
                requestNotifications()
            case "cancelNotifications":
                cancelNotifications()
            case "setTheme":
                saveTheme(body["value"] as? String)
            case "cacheNotificationContent":
                cacheNotificationContent(body["value"] as? [String: Any])
            case "enableBarcodeScanMode":
                enableBarcodeScanMode()
            case "disableBarcodeScanMode":
                disableBarcodeScanMode()
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            disableBarcodeScanMode()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let scheme = url.scheme ?? ""
            let host = url.host ?? ""

            if scheme == "https", host == allowedHost {
                decisionHandler(.allow)
                return
            }

            if scheme == "about", url.absoluteString == "about:blank" {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applySavedTheme()
            applyPadLayoutIfNeeded()
            UserDefaults.standard.set(false, forKey: notificationKey)
            updateWebNotificationState(false)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                let scheme = url.scheme ?? ""
                let host = url.host ?? ""

                if scheme == "https", host == allowedHost {
                    webView.load(URLRequest(url: url))
                }
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            presentJavaScriptDialog(message: message, completionHandler: completionHandler)
        }

        private func requestNotifications() {
            // Temporarily disabled: iOS notification permission requests are paused
            // until FirebaseMessagingService/native FCM migration is implemented.
            UserDefaults.standard.set(false, forKey: notificationKey)
            updateWebNotificationState(false)
        }

        private func cancelNotifications() {
            UserDefaults.standard.set(false, forKey: notificationKey)
            updateWebNotificationState(false)
        }

        func enableBarcodeScanMode() {
            guard !barcodeScanModeEnabled else {
                return
            }
            barcodeScanModeEnabled = true
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            UIApplication.shared.isIdleTimerDisabled = true
        }

        func disableBarcodeScanMode() {
            guard barcodeScanModeEnabled else { return }
            if let brightness = originalBrightness {
                UIScreen.main.brightness = brightness
            }
            originalBrightness = nil
            barcodeScanModeEnabled = false
            UIApplication.shared.isIdleTimerDisabled = false
        }

        @objc private nonisolated func appDidEnterBackground() {
            Task { @MainActor [weak self] in self?.disableBarcodeScanMode() }
        }

        @objc private nonisolated func appWillResignActive() {
            Task { @MainActor [weak self] in self?.disableBarcodeScanMode() }
        }

        private func saveTheme(_ theme: String?) {
            guard theme == "dark" || theme == "light" else {
                return
            }
            UserDefaults.standard.set(theme, forKey: themeKey)
            UserDefaults.standard.set(theme, forKey: "themePreference")
        }

        private func cacheNotificationContent(_ value: [String: Any]?) {
            guard
                let category = value?["category"] as? String,
                let date = value?["date"] as? String,
                let body = value?["body"] as? String
            else {
                return
            }

            NativeLocalNotificationScheduler.cacheContent(
                category: category,
                date: date,
                body: body
            )
        }

        private func applySavedTheme() {
            guard let theme = UserDefaults.standard.string(forKey: themeKey),
                  theme == "dark" || theme == "light" else {
                return
            }

            let script = """
            (function() {
                var theme = '\(theme)';
                try { localStorage.setItem('theme', theme); } catch (error) {}
                document.documentElement.classList.toggle('dark-theme', theme === 'dark');
                document.documentElement.classList.toggle('light-theme', theme === 'light');
                if (document.body) {
                    document.body.classList.toggle('dark-theme', theme === 'dark');
                    document.body.classList.toggle('light-theme', theme === 'light');
                }
            }());
            """
            webView?.evaluateJavaScript(script)
        }

        private func applyPadLayoutIfNeeded() {
            guard usesPadLayout else { return }

            let script = """
            (function() {
                var styleId = 'ghas-ios-pad-layout';
                var css = [
                    'html, body { width: 100% !important; }',
                    '.container { max-width: none !important; width: 100% !important; padding: 32px max(32px, env(safe-area-inset-left)) 44px max(32px, env(safe-area-inset-right)) !important; }',
                    '.header { padding-top: 16px !important; }',
                    '.meal-card { padding: 28px !important; }'
                ].join('\\n');
                var existing = document.getElementById(styleId);
                if (!existing) {
                    existing = document.createElement('style');
                    existing.id = styleId;
                    document.head.appendChild(existing);
                }
                existing.textContent = css;
            }());
            """
            webView?.evaluateJavaScript(script)
        }

        private func updateWebNotificationState(_ enabled: Bool) {
            let script = """
            window.setNativeNotificationEnabled && window.setNativeNotificationEnabled(\(enabled ? "true" : "false"));
            """
            webView?.evaluateJavaScript(script)
        }

        private func presentJavaScriptDialog(message: String, completionHandler: @escaping () -> Void) {
            guard let presenter = topViewController() else {
                completionHandler()
                return
            }

            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
                completionHandler()
            })
            presenter.present(alert, animated: true)
        }

        private func topViewController(
            from root: UIViewController? = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .rootViewController
        ) -> UIViewController? {
            if let navigation = root as? UINavigationController {
                return topViewController(from: navigation.visibleViewController)
            }

            if let tab = root as? UITabBarController {
                return topViewController(from: tab.selectedViewController)
            }

            if let presented = root?.presentedViewController {
                return topViewController(from: presented)
            }

            return root
        }
    }
}

#Preview {
    ContentView()
}
