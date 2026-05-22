import SwiftUI
import UIKit
import WebKit

struct ContentView: View {
    @AppStorage("theme") private var savedTheme = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            GHASLunchWebView()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private var backgroundColor: Color {
        switch savedTheme {
        case "dark":
            return Color(hex: 0x121212)
        case "light":
            return Color(hex: 0xF6F6F6)
        default:
            return colorScheme == .dark ? Color(hex: 0x121212) : Color(hex: 0xF6F6F6)
        }
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
    private let allowedHosts = Set(["ghaslunch1.web.app", "ghaslunch1.firebaseapp.com"])
    private let themeKey = "theme"
    private let notificationKey = "noti-enabled"
    private let usesPadLayout = UIDevice.current.userInterfaceIdiom == .pad

    func makeCoordinator() -> Coordinator {
        Coordinator(
            allowedHosts: allowedHosts,
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

        private let allowedHosts: Set<String>
        private let allowedExternalSchemes = Set(["https", "mailto"])
        private let themeKey: String
        private let notificationKey: String
        private let usesPadLayout: Bool
        weak var webView: WKWebView?

        init(allowedHosts: Set<String>, themeKey: String, notificationKey: String, usesPadLayout: Bool) {
            self.allowedHosts = allowedHosts
            self.themeKey = themeKey
            self.notificationKey = notificationKey
            self.usesPadLayout = usesPadLayout
            super.init()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.frameInfo.securityOrigin.host == "ghaslunch1.web.app",
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
            default:
                break
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme ?? ""
            let host = url.host ?? ""

            if scheme == "https", allowedHosts.contains(host) {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            if allowedExternalSchemes.contains(scheme) {
                UIApplication.shared.open(url)
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

                if scheme == "https", allowedHosts.contains(host) {
                    webView.load(URLRequest(url: url))
                } else if allowedExternalSchemes.contains(scheme) {
                    UIApplication.shared.open(url)
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

        private func saveTheme(_ theme: String?) {
            guard theme == "dark" || theme == "light" else {
                return
            }
            UserDefaults.standard.set(theme, forKey: themeKey)
            UserDefaults.standard.set(theme, forKey: "themePreference")
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
