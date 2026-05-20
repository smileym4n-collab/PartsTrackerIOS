import SwiftUI
import WebKit

struct WebLoginSheet: View {
    let baseURL: URL
    let done: () -> Void

    var body: some View {
        NavigationStack {
            WebLoginView(baseURL: baseURL)
                .navigationTitle("Server Login")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done)
                    }
                }
        }
    }
}

struct WebLoginView: UIViewRepresentable {
    let baseURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: baseURL.appendingPathComponent("login")))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let baseURL: URL

        init(baseURL: URL) {
            self.baseURL = baseURL
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            syncCookies(from: webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            syncCookies(from: webView)
            return .allow
        }

        private func syncCookies(from webView: WKWebView) {
            guard let host = baseURL.host else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                for cookie in cookies where cookie.domain.contains(host) || host.contains(cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        }
    }
}

