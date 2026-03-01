import SwiftUI

struct NicknameSetupView: View {
    @Environment(UserViewModel.self) private var userViewModel
    @State private var nickname = ""
    @State private var appeared = false
    @FocusState private var isTextFieldFocused: Bool

    private var isValid: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 20
    }

    var body: some View {
        ZStack {
            // Gradient background — matches onboarding first page
            LinearGradient(
                colors: [Color(hex: "7161EF"), Color(hex: "4834D4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Hero emoji
                Text("✅")
                    .font(.system(size: 90))
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.1), value: appeared)

                // Title + subtitle
                VStack(spacing: 10) {
                    Text("Welcome to Kai To Do!")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1.0 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.45).delay(0.22), value: appeared)

                    Text("What should we call you?")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .opacity(appeared ? 1.0 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
                }
                .padding(.horizontal, 32)

                // Input field — frosted glass style on gradient
                VStack(spacing: 8) {
                    TextField("Your nickname", text: $nickname)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            if isValid { createProfile() }
                        }
                        .submitLabel(.go)

                    Text("2–20 characters")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 32)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.45).delay(0.38), value: appeared)

                Spacer()

                // Continue button
                Button(action: createProfile) {
                    Text("Let's Go! 🚀")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(isValid ? Color(hex: "4834D4") : Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isValid ? Color.white : Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!isValid)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(appeared ? 1.0 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
            }
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFieldFocused = true
            }
        }
    }

    private func createProfile() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        userViewModel.createProfile(nickname: trimmed)
    }
}

#Preview {
    NicknameSetupView()
        .environment(UserViewModel())
}
