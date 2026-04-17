import SwiftUI

struct LoginView: View {
    @ObservedObject var authVM: AuthViewModel

    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordMismatch = false

    var body: some View {
        ZStack {
            Color.smBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    // Illustration
                    ZStack {
                        Circle()
                            .fill(Color.smYellow400)
                            .frame(width: 100, height: 100)
                        Text("📖")
                            .font(.system(size: 48))
                    }
                    .padding(.bottom, 8)

                    // Title & Subtitle
                    VStack(spacing: 6) {
                        Text(isRegistering ? "Create account" : "Welcome back")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.smCoral400)

                        Text(isRegistering ? "Start your story journey" : "Sign in to read your stories")
                            .font(.system(size: 14))
                            .foregroundColor(.smTextSecondary)
                    }

                    // Form Card
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding(14)
                            .background(Color.smNeutral50)
                            .cornerRadius(12)

                        SecureField("Password", text: $password)
                            .textContentType(isRegistering ? .newPassword : .password)
                            .padding(14)
                            .background(Color.smNeutral50)
                            .cornerRadius(12)

                        if isRegistering {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding(14)
                                .background(Color.smNeutral50)
                                .cornerRadius(12)

                            Text("Password must be at least 6 characters")
                                .font(.system(size: 11))
                                .foregroundColor(.smTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if passwordMismatch {
                                Text("Passwords do not match")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.smRed400)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Primary CTA
                        Button {
                            Task { await handleSubmit() }
                        } label: {
                            HStack(spacing: 8) {
                                if authVM.isLoading {
                                    ProgressView()
                                        .tint(isRegistering ? .white : .smTextPrimary)
                                }
                                Text(isRegistering ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isRegistering ? Color.smCoral400 : Color.smYellow400)
                            .foregroundColor(isRegistering ? .white : .smTextPrimary)
                            .cornerRadius(14)
                        }
                        .disabled(authVM.isLoading)

                        // Error message
                        if let error = authVM.errorMessage {
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.smRed400)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    .padding(.horizontal, 20)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.smNeutral100).frame(height: 1)
                        Text("or")
                            .font(.system(size: 12))
                            .foregroundColor(.smTextSecondary)
                            .padding(.horizontal, 8)
                        Rectangle().fill(Color.smNeutral100).frame(height: 1)
                    }
                    .padding(.horizontal, 40)

                    // Toggle mode
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRegistering.toggle()
                            passwordMismatch = false
                            authVM.errorMessage = nil
                        }
                    } label: {
                        if isRegistering {
                            Text("Already have an account? ")
                                .foregroundColor(.smTextSecondary) +
                            Text("Sign In")
                                .foregroundColor(.smYellow500)
                                .bold()
                        } else {
                            Text("Don't have an account? ")
                                .foregroundColor(.smTextSecondary) +
                            Text("Create one")
                                .foregroundColor(.smCoral400)
                                .bold()
                        }
                    }
                    .font(.system(size: 14))

                    Spacer().frame(height: 20)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func handleSubmit() async {
        passwordMismatch = false
        if isRegistering {
            guard password == confirmPassword else {
                passwordMismatch = true
                return
            }
            await authVM.signUp(email: email, password: password)
        } else {
            await authVM.signIn(email: email, password: password)
        }
    }
}
