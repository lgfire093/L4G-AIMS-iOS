import SwiftUI

struct RegisterView: View {
    var onRegistered: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: KeyAuthClient

    @State private var username = ""
    @State private var password = ""
    @State private var license = ""
    @State private var busy = false
    @State private var notice: String?
    @State private var noticeColor = Theme.cyan

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CREATE ACCOUNT")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .tracking(1.5)
                                .foregroundColor(Theme.textPrimary)
                            Text("A license key is required")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.textDim)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .padding(9)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                    }
                    .padding(.top, 18)

                    GlassCard(accent: Theme.violet) {
                        VStack(alignment: .leading, spacing: 13) {
                            label("USERNAME")
                            TextField("", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textContentType(.username)
                                .modifier(DarkField())

                            label("PASSWORD")
                            SecureField("", text: $password)
                                .textContentType(.newPassword)
                                .modifier(DarkField())

                            label("LICENSE KEY")
                            TextField("", text: $license)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled(true)
                                .modifier(DarkField())

                            if let notice {
                                Text(notice)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(noticeColor)
                            }

                            Button {
                                submit()
                            } label: {
                                HStack(spacing: 8) {
                                    if busy {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(Theme.bg)
                                    }
                                    Text(busy ? "REGISTERING..." : "REGISTER")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(tint: Theme.violet, solid: true))
                            .disabled(busy)
                            .opacity(busy ? 0.7 : 1)
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(1.4)
            .foregroundColor(Theme.textDim)
    }

    private func submit() {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = license.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !user.isEmpty else { notice = "Username required."; noticeColor = Theme.crimson; return }
        guard !pass.isEmpty else { notice = "Password required."; noticeColor = Theme.crimson; return }
        guard !key.isEmpty else { notice = "License key required."; noticeColor = Theme.crimson; return }

        busy = true
        notice = "Registering with KeyAuth..."
        noticeColor = Theme.cyan

        Task {
            let error = await auth.register(user: user, password: pass, license: key)
            busy = false
            if let error {
                notice = "Registration failed: \(error)"
                noticeColor = Theme.crimson
            } else {
                notice = "Registration successful."
                noticeColor = Theme.neonGreen
                onRegistered(user)
                dismiss()
            }
        }
    }
}
