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

        Task {
            do {
                // Find the shared list by invite code
                if let (record, tasks) = try await CloudKitService.shared.fetchSharedList(byInviteCode: inviteCode) {
                    // Create local copy of the shared list
                    let sharedList = TodoList(
                        name: record["name"] as? String ?? "Shared List",
                        color: record["color"] as? String ?? "7161EF",
                        tasks: tasks,
                        cloudRecordID: record.recordID.recordName,
                        isShared: true,
                        shareType: .participant,
                        ownerID: record["ownerID"] as? String,
                        ownerName: record["ownerName"] as? String,
                        inviteCode: inviteCode
                    )

                    // Add self as participant on CloudKit
                    try await CloudKitService.shared.addParticipant(
                        userID: userViewModel.userID,
                        userName: userViewModel.nickname,
                        toListRecord: record
                    )

                    await MainActor.run {
                        // Check if we already have this list
                        if !listsViewModel.lists.contains(where: { $0.cloudRecordID == record.recordID.recordName }) {
                            listsViewModel.lists.append(sharedList)
                            listsViewModel.saveLists()
                        }
                        isJoining = false
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        isJoining = false
                        errorMessage = "No list found with that code. Please check and try again."
                    }
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                    errorMessage = "Failed to join: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    JoinListSheet()
        .environment(ListsViewModel())
        .environment(UserViewModel())
}
