import SwiftUI
import UIKit
import WebKit

extension Notification.Name {
    static let nativeNotificationSettingsDidChange = Notification.Name("nativeNotificationSettingsDidChange")
}

struct ContentView: View {
    @AppStorage("theme") private var savedTheme = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var presentsNotificationSettings = false

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            GHASLunchWebView()
                .ignoresSafeArea(.container, edges: .bottom)

            VStack {
                HStack(spacing: 6) {
                    Spacer()
                    Button {
                        presentsNotificationSettings = true
                    } label: {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 38, height: 38)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("알림 설정")
                    Button {
                        presentNativeShareSheet()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 38, height: 38)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("공유하기")
                }
                .padding(.trailing, 24)
                .padding(.top, 30)
                Spacer()
            }
        }
        .sheet(isPresented: $presentsNotificationSettings) {
            NotificationSettingsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func presentNativeShareSheet() {
        guard let url = URL(string: "https://ghaslunch1.web.app"),
              let presenter = topViewController()
        else {
            return
        }

        let message = "경기자동차과학고등학교 급식 및 시간표 확인 앱!"
        let activityController = UIActivityViewController(activityItems: [message, url], applicationActivities: nil)
        activityController.setValue("GHAS 오늘의 급식", forKey: "subject")

        if let popover = activityController.popoverPresentationController,
           let sourceView = presenter.view {
            popover.sourceView = sourceView
            popover.sourceRect = CGRect(
                x: sourceView.bounds.maxX - 44,
                y: sourceView.safeAreaInsets.top + 34,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = [.up, .right]
        }

        presenter.present(activityController, animated: true)
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

    private var backgroundColor: Color {
        switch savedTheme {
        case "dark":
            return AppTheme.darkBackground
        case "light":
            return AppTheme.lightBackground
        default:
            return AppTheme.background(colorScheme)
        }
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
        // Keep the web view transparent so the resolved theme background shows through
        // immediately and the page never flashes a light frame before it paints.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.alpha = 0
        // Honour an explicit saved theme, otherwise follow the system appearance so the
        // very first frame matches the page background.
        let initialTheme = UserDefaults.standard.string(forKey: themeKey) ?? ""
        let prefersDark: Bool
        switch initialTheme {
        case "dark": prefersDark = true
        case "light": prefersDark = false
        default: prefersDark = UITraitCollection.current.userInterfaceStyle == .dark
        }
        webView.underPageBackgroundColor = prefersDark
            ? UIColor(hex: 0x121212)
            : UIColor(hex: 0xF6F6F6)
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
        // Clear only HTTP caches; localStorage and other persistent storage
        // must be preserved so user data (e.g. student code image) survives restarts.
        let cacheTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
        ]
        WKWebsiteDataStore.default().removeData(
            ofTypes: cacheTypes,
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
                }
            };
            if (savedTheme === 'dark' || savedTheme === 'light') {
                try { localStorage.setItem('theme', savedTheme); } catch (error) {}
                document.documentElement.classList.toggle('dark-theme', savedTheme === 'dark');
                document.documentElement.classList.toggle('light-theme', savedTheme === 'light');
                var applyBodyTheme = function() {
                    if (!document.body) return;
                    document.body.classList.toggle('dark-theme', savedTheme === 'dark');
                    document.body.classList.toggle('light-theme', savedTheme === 'light');
                };
                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', applyBodyTheme, { once: true });
                } else {
                    applyBodyTheme();
                }
            }
            window.GHASAndroidApp = bridge;
            window.GHASAndroidNotifications = bridge;
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
                selector: #selector(nativeNotificationSettingsDidChange(_:)),
                name: .nativeNotificationSettingsDidChange,
                object: nil
            )
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
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
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

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            revealWebView(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            revealWebView(webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            revealWebView(webView)
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
            hideWebShareButton()
            let enabled = NativeNotificationSettings.load().enabled
            UserDefaults.standard.set(enabled, forKey: notificationKey)
            updateWebNotificationState(enabled)
            revealWebView(webView)
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
            Task {
                // The web bell is a simple on/off, so it enables every category at once.
                var settings = NativeNotificationSettings.load()
                settings.setAllCategories(enabled: true)
                settings.save()
                let allowed = await NativeNotificationService.applySavedSettings()
                await MainActor.run {
                    UserDefaults.standard.set(allowed, forKey: notificationKey)
                    updateWebNotificationState(allowed)
                }
            }
        }

        private func cancelNotifications() {
            // The web bell OFF is the explicit "모든 알림 끄기" action: turn every category off,
            // persist, reconcile (cancels all pending requests) and report the aggregate as OFF.
            Task {
                var settings = NativeNotificationSettings.load()
                settings.setAllCategories(enabled: false)
                settings.save()
                _ = await NativeNotificationService.applySavedSettings()
                await MainActor.run {
                    UserDefaults.standard.set(false, forKey: notificationKey)
                    updateWebNotificationState(false)
                }
            }
        }

        @objc private func nativeNotificationSettingsDidChange(_ notification: Notification) {
            guard let enabled = notification.userInfo?["enabled"] as? Bool else {
                return
            }
            UserDefaults.standard.set(enabled, forKey: notificationKey)
            updateWebNotificationState(enabled)
        }

        func enableBarcodeScanMode() {
            guard !barcodeScanModeEnabled else { return }
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

        @objc private nonisolated func appDidBecomeActive() {
            Task { @MainActor [weak self] in self?.restoreBarcodeScanModeIfModalOpen() }
        }

        private func restoreBarcodeScanModeIfModalOpen() {
            webView?.evaluateJavaScript(
                "(function(){var el=document.getElementById('student-code-modal');return !!(el&&el.classList.contains('open'));})()"
            ) { [weak self] result, _ in
                guard result as? Bool == true else { return }
                self?.enableBarcodeScanMode()
            }
        }

        private func hideWebShareButton() {
            webView?.evaluateJavaScript(
                "(function(){var el=document.getElementById('btn-share');if(el)el.style.display='none';})()",
                completionHandler: nil
            )
        }

        private func saveTheme(_ theme: String?) {
            guard theme == "dark" || theme == "light" else {
                return
            }
            UserDefaults.standard.set(theme, forKey: themeKey)
            UserDefaults.standard.set(theme, forKey: "themePreference")
            webView?.underPageBackgroundColor = theme == "dark"
                ? UIColor(hex: 0x121212)
                : UIColor(hex: 0xF6F6F6)
            webView?.backgroundColor = .clear
            webView?.scrollView.backgroundColor = .clear
            UIWindow.appearance().backgroundColor = theme == "dark"
                ? UIColor(hex: 0x121212)
                : UIColor(hex: 0xF6F6F6)
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

        private func revealWebView(_ webView: WKWebView) {
            guard webView.alpha == 0 else { return }
            UIView.performWithoutAnimation {
                webView.alpha = 1
            }
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
