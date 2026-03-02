import SwiftUI

struct NicknameSetupView: View {
    @Environment(UserViewModel.self) private var userViewModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Gradient background — only re-renders when `appeared` changes (once on mount),
            // NOT on every keystroke. Static colors are pre-computed below.
            LinearGradient(
                colors: [Self.gradientTop, Self.gradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Hero emoji — unaffected by typing, animates only on appear
                Text("✅")
                    .font(.system(size: 90))
                    .scaleEffect(appeared ? 1.0 : 0.4)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.1), value: appeared)

                // Title + subtitle — unaffected by typing
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

                // Input + button live in an isolated child view.
                // All keystroke-driven state (@State nickname, @FocusState) is owned HERE —
                // typing only re-renders NicknameInputSection; the gradient, emoji, and titles
                // above are completely untouched, eliminating the per-keystroke re-render of
                // heavy static content.
                NicknameInputSection(appeared: appeared) { nickname in
                    userViewModel.createProfile(nickname: nickname)
                }
                .frame(maxHeight: .infinity) // fills remaining space so button stays at bottom
            }
        }
        .onAppear {
            appeared = true
        }
    }

    // Pre-computed static colors — Scanner + hex parse runs once at type-load, not per keystroke.
    private static let gradientTop    = Color(hex: "7161EF")
    private static let gradientBottom = Color(hex: "4834D4")
}

// MARK: - NicknameInputSection

/// Isolated child view that owns all nickname-typing state.
///
/// **Why a separate view?** SwiftUI re-renders the view that OWNS a @State property whenever
/// that property changes. By moving `nickname` here, only this lightweight view re-renders on
/// every keystroke — the parent (gradient, emoji, animated titles) stays frozen, cutting
/// per-keypress work from ~8 view subtrees to ~2.
private struct NicknameInputSection: View {
    let appeared: Bool
    let onSubmit: (String) -> Void

    @State private var nickname = ""
    @FocusState private var isFocused: Bool

    /// Cheap validation — runs only inside this isolated view, not the full parent tree.
    private var isValid: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 20
    }

    var body: some View {
        VStack {
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
                    .focused($isFocused)
                    .onSubmit {
                        if isValid { submit() }
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

            // Continue button — pinned to bottom via Spacer above
            Button(action: submit) {
                Text("Let's Go! 🚀")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isValid ? Self.buttonTextColor : Color.white.opacity(0.5))
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
        .onAppear {
            // Delay focus slightly so the sheet/appear animation completes first —
            // avoids the keyboard intercepting the initial spring animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isFocused = true
            }
        }
    }

    private func submit() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 && trimmed.count <= 20 else { return }
        onSubmit(trimmed)
    }

    // Pre-computed static color — no Scanner allocation per render.
    private static let buttonTextColor = Color(hex: "4834D4")
}

#Preview {
    NicknameSetupView()
        .environment(UserViewModel())
}
