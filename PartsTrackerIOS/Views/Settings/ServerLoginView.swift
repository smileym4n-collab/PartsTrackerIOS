import SwiftUI

struct ServerLoginView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var webLoginPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SummaryBanner(
                        title: "Connect Server",
                        subtitle: "Point the app at your inventory backend, then use the existing session login.",
                        systemImage: "server.rack",
                        tint: .blue
                    )
                }

                Section {
                    TextField("http://inventory.local:5000", text: $serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        sessionManager.saveServerURL(serverURL)
                        Task { await sessionManager.refreshState() }
                    } label: {
                        Label("Check Server", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("Use the same address you open for the existing web app.")
                }

                Section("State") {
                    ServerStateRows()
                }

                Section {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    Button {
                        sessionManager.saveServerURL(serverURL)
                        Task { await sessionManager.login(username: username, password: password) }
                    } label: {
                        Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                } header: {
                    Text("Local Login")
                } footer: {
                    Text("This posts to the existing Flask login page and stores only the normal session cookie.")
                }

                Section {
                    Button {
                        sessionManager.saveServerURL(serverURL)
                        webLoginPresented = true
                    } label: {
                        Label("Open Server Login Page", systemImage: "safari")
                    }
                    .disabled(sessionManager.serverURL == nil && URL(string: serverURL) == nil)
                } header: {
                    Text("Web Login")
                } footer: {
                    Text("Use this for Microsoft sign-in or any server-rendered login flow.")
                }
            }
            .navigationTitle("Parts Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if case .checking = sessionManager.authState {
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $webLoginPresented, onDismiss: {
                Task { await sessionManager.refreshAfterWebLogin() }
            }) {
                if let url = sessionManager.serverURL {
                    WebLoginSheet(baseURL: url) {
                        webLoginPresented = false
                    }
                } else {
                    ContentUnavailableView("Server Needed", systemImage: "server.rack")
                }
            }
            .onAppear {
                serverURL = sessionManager.serverURLString
            }
        }
    }
}

struct HealthAboutView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var webLoginPresented = false
    @State private var serverURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SummaryBanner(
                        title: "Server Status",
                        subtitle: serverSubtitle,
                        systemImage: "server.rack",
                        tint: stateTint
                    )
                }

                Section("Server") {
                    TextField("Server Address", text: $serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    ServerStateRows()
                    Button {
                        sessionManager.saveServerURL(serverURL)
                        Task { await sessionManager.refreshState() }
                    } label: {
                        Label("Save and Check Server", systemImage: "checkmark.circle")
                    }
                    Button {
                        Task { await sessionManager.refreshState() }
                    } label: {
                        Label("Refresh Status", systemImage: "arrow.clockwise")
                    }
                }

                if let health = sessionManager.health {
                    Section("Health") {
                        DetailRow("Overall", health.status)
                        DetailRow("API", health.api.status)
                        DetailRow("API Version", health.api.version)
                        DetailRow("App", health.app.status)
                        DetailRow("Backend Version", health.app.version)
                    }
                }

                Section("Session") {
                    Button {
                        webLoginPresented = true
                    } label: {
                        Label("Open Server Login Page", systemImage: "safari")
                    }

                    Button(role: .destructive) {
                        Task { await sessionManager.forgetSession() }
                    } label: {
                        Label("Forget Local Session", systemImage: "trash")
                    }
                }

                Section("App") {
                    DetailRow("Mode", "Read-only companion")
                    DetailRow("Minimum iOS", "17.0")
                    DetailRow("Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
                }
            }
            .navigationTitle("Server")
            .onAppear {
                serverURL = sessionManager.serverURLString
            }
            .sheet(isPresented: $webLoginPresented, onDismiss: {
                Task { await sessionManager.refreshAfterWebLogin() }
            }) {
                if let url = sessionManager.serverURL {
                    WebLoginSheet(baseURL: url) {
                        webLoginPresented = false
                    }
                }
            }
        }
    }

    private var serverSubtitle: String {
        switch sessionManager.authState {
        case .authenticated:
            return "Connected and ready for read-only inventory browsing."
        case .forbidden:
            return "Connected, but this account has limited inventory permissions."
        case .unauthenticated:
            return "Server is reachable. Log in to continue."
        case .checking:
            return "Checking the configured server."
        case .offline:
            return "The configured server could not be reached."
        case .unconfigured:
            return "No backend server has been configured yet."
        }
    }

    private var stateTint: Color {
        switch sessionManager.authState {
        case .authenticated:
            return .green
        case .forbidden, .unauthenticated:
            return .orange
        case .checking:
            return .blue
        case .offline:
            return .red
        case .unconfigured:
            return .gray
        }
    }
}

private struct ServerStateRows: View {
    @EnvironmentObject private var sessionManager: SessionManager

    var body: some View {
        HStack {
            Text("Login")
                .foregroundStyle(.secondary)
            Spacer()
            StatusPill(text: stateText, systemImage: stateIcon, tint: stateTint)
        }
        if let message = sessionManager.message?.nilIfBlank {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var stateText: String {
        switch sessionManager.authState {
        case .unconfigured:
            return "Server not configured"
        case .checking:
            return "Checking"
        case .unauthenticated:
            return "Login needed"
        case .authenticated:
            return "Ready"
        case .forbidden:
            return "Permission limited"
        case .offline:
            return "Unreachable"
        }
    }

    private var stateIcon: String {
        switch sessionManager.authState {
        case .authenticated:
            return "checkmark.circle"
        case .forbidden:
            return "lock.trianglebadge.exclamationmark"
        case .unauthenticated:
            return "person.crop.circle.badge.exclamationmark"
        case .checking:
            return "arrow.clockwise"
        case .offline:
            return "wifi.exclamationmark"
        case .unconfigured:
            return "questionmark.circle"
        }
    }

    private var stateTint: Color {
        switch sessionManager.authState {
        case .authenticated:
            return .green
        case .forbidden, .unauthenticated:
            return .orange
        case .checking:
            return .blue
        case .offline:
            return .red
        case .unconfigured:
            return .gray
        }
    }
}
