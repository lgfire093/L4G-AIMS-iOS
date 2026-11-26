import SwiftUI

struct LoginView: View {
    var onAuthenticated: () -> Void

    @EnvironmentObject private var auth: KeyAuthClient

    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var busy = false
    @State private var notice: String?
    @State private var noticeColor = Theme.cyan
    @State private var showRegister = false
    @State private var appeared = false

    private let defaults = UserDefaults.standard

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 46)
                brand
                loginCard
                footer
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
        }
        .onAppear {
            loadRemembered()
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView { createdUser in
                username = createdUser
                password = ""
                notice = "Account created. Sign in with your new credentials."
                noticeColor = Theme.neonGreen
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var brand: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Theme.cyan.opacity(0.25), lineWidth: 1)
                    .frame(width: 116, height: 116)
                Circle()
                    .stroke(Theme.cyan.opacity(0.10), lineWidth: 12)
                    .frame(width: 88, height: 88)
                Text("L4G")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundColor(Theme.cyan)
                    .shadow(color: Theme.cyan.opacity(0.6), radius: 12)
            }
            VStack(spacing: 4) {
                Text("L4G AIMS")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundColor(Theme.textPrimary)
                Text("PC PANEL CONTROLLER")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundColor(Theme.textDim)
            }
        }
    }

    private var loginCard: some View {
        GlassCard(accent: Theme.cyan) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    SectionLabel(text: "Secure sign in", color: Theme.cyan)
                    Spacer()
                    StatusPill(text: "KeyAuth", color: Theme.violet)
                }

                fieldLabel("USERNAME")
                TextField("", text: $username)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.username)
                    .keyboardType(.asciiCapable)
                    .modifier(DarkField())

                fieldLabel("PASSWORD")
                SecureField("", text: $password)
                    .textFieldStyle(.plain)
                    .textContentType(.password)
                    .modifier(DarkField())

                Toggle(isOn: $rememberMe) {
                    Text("Remember me")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                }
                .tint(Theme.cyan)
                .padding(.top, 2)

                if let notice {
                    Text(notice)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(noticeColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    attemptLogin()
                } label: {
                    HStack(spacing: 8) {
                        if busy {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Theme.bg)
                        }
                        Text(busy ? "AUTHENTICATING..." : "SIGN IN")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.cyan, solid: true))
                .disabled(busy)
                .opacity(busy ? 0.7 : 1)
                .padding(.top, 4)

                Button {
                    showRegister = true
                } label: {
                    Text("CREATE ACCOUNT")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.violet))

                Text("Use the same KeyAuth account as the Android client.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textDim)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 5) {
            Text("L4G AIMS  ·  v\(AppConfig.bundleVersion)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textDim)
            Text("LAN ONLY  ·  ENCRYPTED SESSION")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundColor(Theme.textDim.opacity(0.7))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(1.4)
            .foregroundColor(Theme.textDim)
    }

    private func loadRemembered() {
        guard defaults.bool(forKey: AppConfig.DefaultsKey.rememberMe) else { return }
        rememberMe = true
        username = defaults.string(forKey: AppConfig.DefaultsKey.savedUser) ?? ""
        password = defaults.string(forKey: AppConfig.DefaultsKey.savedPass) ?? ""
    }

    private func attemptLogin() {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty else {
            notice = "Username required."
            noticeColor = Theme.crimson
            return
        }
        guard !pass.isEmpty else {
            notice = "Password required."
            noticeColor = Theme.crimson
            return
        }

        if rememberMe {
            defaults.set(true, forKey: AppConfig.DefaultsKey.rememberMe)
            defaults.set(user, forKey: AppConfig.DefaultsKey.savedUser)
            defaults.set(pass, forKey: AppConfig.DefaultsKey.savedPass)
        } else {
            defaults.set(false, forKey: AppConfig.DefaultsKey.rememberMe)
            defaults.removeObject(forKey: AppConfig.DefaultsKey.savedUser)
            defaults.removeObject(forKey: AppConfig.DefaultsKey.savedPass)
        }

        busy = true
        notice = "Authenticating with KeyAuth..."
        noticeColor = Theme.cyan

        Task {
            let error = await auth.login(user: user, password: pass)
            busy = false
            if let error {
                notice = "Login failed: \(error)"
                noticeColor = Theme.crimson
            } else {
                notice = "Access granted."
                noticeColor = Theme.neonGreen
                onAuthenticated()
            }
        }
    }
}

struct DarkField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.black.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Theme.cyan.opacity(0.30), lineWidth: 1)
            )
    }
}
