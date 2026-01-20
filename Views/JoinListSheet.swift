import SwiftUI

struct JoinListSheet: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    private var isValidCode: Bool {
        inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).count == 6
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.kaiTeal)

                    Text("Join a List")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter the 6-character invite code\nshared with you")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                Spacer()

                // Code input
                VStack(spacing: 16) {
                    TextField("INVITE CODE", text: $inviteCode)
                        .textFieldStyle(.plain)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isTextFieldFocused)
                        .onChange(of: inviteCode) { _, newValue in
                            inviteCode = String(newValue.uppercased().prefix(6))
                        }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Join button
                Button {
                    joinList()
                } label: {
                    Group {
                        if isJoining {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Join List")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidCode ? Color.kaiTeal : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValidCode || isJoining)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func joinList() {
        isJoining = true
        errorMessage = nil

        // In a real implementation, this would call CloudKitService to find and join the list
        // For now, we'll show an error since local-only joining isn't possible
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay

            await MainActor.run {
                isJoining = false
                errorMessage = "Could not find list. Make sure the code is correct and you have an internet connection."
            }
        }
    }
}

#Preview {
    JoinListSheet()
        .environment(ListsViewModel())
        .environment(UserViewModel())
}
