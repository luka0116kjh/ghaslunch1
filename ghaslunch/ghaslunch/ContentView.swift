import SwiftUI
import UIKit
import UserNotifications
import WebKit

struct ContentView: View {
    var body: some View {
        GHASLunchWebView()
            .ignoresSafeArea()
    }
}

struct GHASLunchWebView: UIViewRepresentable {
    private let appURL = URL(string: "https://ghaslunch1.web.app/")!
    private let allowedHosts = Set(["ghaslunch1.web.app", "ghaslunch1.firebaseapp.com"])
    private let themeKey = "theme"
    private let notificationKey = "noti-enabled"

    func makeCoordinator() -> Coordinator {
        Coordinator(
            allowedHosts: allowedHosts,
            themeKey: themeKey,
            notificationKey: notificationKey
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
                forMainFrameOnly: false
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.webView = webView
        webView.load(
            URLRequest(
                url: appURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
        )
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
                }
            };
            window.GHASAndroidApp = bridge;
            window.GHASAndroidNotifications = bridge;
        }());
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let messageHandlerName = "ghasNative"

        private let allowedHosts: Set<String>
        private let themeKey: String
        private let notificationKey: String
        weak var webView: WKWebView?

        init(allowedHosts: Set<String>, themeKey: String, notificationKey: String) {
            self.allowedHosts = allowedHosts
            self.themeKey = themeKey
            self.notificationKey = notificationKey
            super.init()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
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

            if url.scheme == "http" || url.scheme == "https" {
                let host = url.host ?? ""
                if allowedHosts.contains(host) {
                    decisionHandler(.allow)
                } else {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                }
                return
            }

            if url.scheme == "about" {
                decisionHandler(.allow)
            } else {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applySavedTheme()
            let enabled = UserDefaults.standard.bool(forKey: notificationKey)
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
                webView.load(URLRequest(url: url))
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
            let defaultsKey = notificationKey
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    UserDefaults.standard.set(granted, forKey: defaultsKey)
                    self.updateWebNotificationState(granted)
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }

        private func cancelNotifications() {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            UserDefaults.standard.set(false, forKey: notificationKey)
            updateWebNotificationState(false)
        }

        private func saveTheme(_ theme: String?) {
            guard theme == "dark" || theme == "light" else {
                return
            }
            UserDefaults.standard.set(theme, forKey: themeKey)
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
