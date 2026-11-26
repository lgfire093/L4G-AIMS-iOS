import SwiftUI

struct RootView: View {
    @StateObject private var auth = KeyAuthClient()
    @State private var authenticated = false

    var body: some View {
        ZStack {
            ScreenBackground()
            if authenticated {
                DashboardView(onLogout: {
                    auth.logout()
                    authenticated = false
                })
                .environmentObject(auth)
                .transition(.opacity)
            } else {
                LoginView(onAuthenticated: {
                    authenticated = true
                })
                .environmentObject(auth)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authenticated)
    }
}
