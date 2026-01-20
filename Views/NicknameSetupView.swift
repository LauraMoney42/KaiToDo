import SwiftUI

struct NicknameSetupView: View {
    @Environment(UserViewModel.self) private var userViewModel
    @State private var nickname = ""
    @FocusState private var isTextFieldFocused: Bool

    private var isValid: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 20
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.kaiPurple)

            // Title
            VStack(spacing: 8) {
                Text("Welcome to KaiToDo")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Enter your nickname to get started")
                    .foregroundStyle(.secondary)
            }

            // Input
            VStack(spacing: 8) {
                TextField("Your nickname", text: $nickname)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if isValid {
                            createProfile()
                        }
                    }

                Text("2-20 characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            Button(action: createProfile) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? Color.kaiPurple : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .onAppear {
            isTextFieldFocused = true
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
