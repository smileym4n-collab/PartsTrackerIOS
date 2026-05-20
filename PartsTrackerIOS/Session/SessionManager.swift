import Foundation

@MainActor
final class SessionManager: ObservableObject {
    enum AuthState: Equatable {
        case unconfigured
        case checking
        case unauthenticated
        case authenticated
        case forbidden
        case offline(String)
    }

    @Published var serverURLString: String {
        didSet {
            UserDefaults.standard.set(serverURLString, forKey: Self.serverURLKey)
            updateClient()
        }
    }
    @Published private(set) var authState: AuthState = .unconfigured
    @Published private(set) var health: HealthResponse?
    @Published var message: String?

    private static let serverURLKey = "serverURLString"
    private(set) var apiClient: APIClient?

    var isReadyForInventory: Bool {
        authState == .authenticated || authState == .forbidden
    }

    var serverURL: URL? {
        URL(string: serverURLString.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    init() {
        self.serverURLString = UserDefaults.standard.string(forKey: Self.serverURLKey) ?? ""
        updateClient()
        authState = apiClient == nil ? .unconfigured : .checking
    }

    func saveServerURL(_ value: String) {
        serverURLString = normalizedServerString(value)
        updateClient()
    }

    func refreshState() async {
        updateClient()
        guard let apiClient else {
            authState = .unconfigured
            health = nil
            return
        }

        authState = .checking
        do {
            health = try await apiClient.health()
            _ = try await apiClient.parts(page: 1, perPage: 1)
            authState = .authenticated
            message = nil
        } catch APIClientError.unauthorized {
            authState = .unauthenticated
            message = "Server is reachable. Log in to continue."
        } catch APIClientError.forbidden {
            authState = .forbidden
            message = "Logged in, but this account cannot view parts."
        } catch {
            authState = .offline(error.localizedDescription)
            message = error.localizedDescription
        }
    }

    func login(username: String, password: String) async {
        guard let apiClient else {
            message = "Enter a valid server address first."
            return
        }
        authState = .checking
        do {
            try await apiClient.login(username: username, password: password)
            await refreshState()
        } catch {
            authState = .unauthenticated
            message = error.localizedDescription
        }
    }

    func forgetSession() async {
        guard let serverURL else { return }
        let host = serverURL.host
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies where host == nil || cookie.domain.contains(host ?? "") {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        authState = .unauthenticated
        message = "Session cookies were cleared on this device."
    }

    func refreshAfterWebLogin() async {
        await refreshState()
    }

    private func updateClient() {
        guard let url = serverURL, url.scheme != nil, url.host != nil else {
            apiClient = nil
            return
        }

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = .shared
        apiClient = APIClient(baseURL: url, session: URLSession(configuration: configuration))
    }

    private func normalizedServerString(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") {
            return trimmed
        }
        return "http://\(trimmed)"
    }
}

