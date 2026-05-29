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
                Spacer()
                HStack {
                    Spacer()
                    NotificationSettingsCardButton {
                        presentsNotificationSettings = true
                    }
                }
                .padding(.trailing, 14)
                .padding(.bottom, 14)
            }
        }
        .sheet(isPresented: $presentsNotificationSettings) {
            NotificationSettingsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
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
        webView.backgroundColor = .clear
        webView.isOpaque = false
        let initialTheme = UserDefaults.standard.string(forKey: themeKey) ?? ""
        if initialTheme == "dark" {
            webView.underPageBackgroundColor = UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1)
        } else if initialTheme == "light" {
            webView.underPageBackgroundColor = UIColor(red: 246/255, green: 246/255, blue: 246/255, alpha: 1)
        }
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
            let enabled = NativeNotificationSettings.load().enabled
            UserDefaults.standard.set(enabled, forKey: notificationKey)
            updateWebNotificationState(enabled)
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
                var settings = NativeNotificationSettings.load()
                settings.enabled = true
                settings.save()
                let allowed = await NativeNotificationService.applySavedSettings()
                if !allowed {
                    settings.enabled = false
                    settings.save()
                }
                await MainActor.run {
                    UserDefaults.standard.set(allowed, forKey: notificationKey)
                    updateWebNotificationState(allowed)
                }
            }
        }

        private func cancelNotifications() {
            Task {
                await NativeNotificationService.disableNotifications()
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

        private func saveTheme(_ theme: String?) {
            guard theme == "dark" || theme == "light" else {
                return
            }
            UserDefaults.standard.set(theme, forKey: themeKey)
            UserDefaults.standard.set(theme, forKey: "themePreference")
            webView?.underPageBackgroundColor = theme == "dark"
                ? UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1)
                : UIColor(red: 246/255, green: 246/255, blue: 246/255, alpha: 1)
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
