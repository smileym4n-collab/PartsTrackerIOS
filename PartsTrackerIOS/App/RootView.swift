import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    var body: some View {
        Group {
            if sessionManager.isReadyForInventory {
                AppShellView()
            } else {
                ServerLoginView()
            }
        }
        .task {
            await sessionManager.refreshState()
        }
    }
}

