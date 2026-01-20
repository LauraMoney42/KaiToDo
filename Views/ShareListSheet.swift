import SwiftUI

struct ShareListSheet: View {
    let listID: UUID

    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inviteCode: String?
    @State private var copied = false
    @State private var isSharing = false
    @State private var errorMessage: String?

    private var list: TodoList? {
        listsViewModel.getList(by: listID)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.kaiPurple)

                    Text("Share List")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let list = list {
                        Text("Share \"\(list.name)\" with family & friends")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 24)

                Spacer()

                // Invite code display
                if let code = inviteCode ?? list?.inviteCode {
                    VStack(spacing: 16) {
                        Text("Invite Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(code)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(.kaiPurple)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            UIPasteboard.general.string = code
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .fontWeight(.medium)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Button {
                            shareList()
                        } label: {
                            Group {
                                if isSharing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Label("Generate Invite Code", systemImage: "link")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSharing ? Color.gray : Color.kaiPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isSharing)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Participants
                if let list = list, !list.participants.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Participants")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(list.participants) { participant in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(.secondary)
                                Text(participant.name)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 32)
                }

                // Share button
                if inviteCode != nil || list?.inviteCode != nil {
                    ShareLink(
                        item: "Join my KaiToDo list! Use code: \(inviteCode ?? list?.inviteCode ?? "")",
                        subject: Text("Join my KaiToDo list"),
                        message: Text("Use this code to join my list in KaiToDo")
                    ) {
                        Label("Share via Messages", systemImage: "message.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func shareList() {
        isSharing = true
        errorMessage = nil

        // Generate invite code locally first
        guard let code = listsViewModel.shareList(
            listID,
            ownerID: userViewModel.userID,
            ownerName: userViewModel.nickname
        ) else {
            isSharing = false
            errorMessage = "Failed to generate invite code"
            return
        }

        // Save to CloudKit
        Task {
            do {
                if let list = listsViewModel.getList(by: listID) {
                    let record = try await CloudKitService.shared.saveSharedList(
                        list,
                        ownerID: userViewModel.userID,
                        ownerName: userViewModel.nickname
                    )

                    // Also save all existing tasks to CloudKit
                    for task in list.tasks {
                        _ = try await CloudKitService.shared.saveTask(task, listRecordID: record.recordID)
                    }

                    // Create invitation record for lookup
                    _ = try await CloudKitService.shared.createInvitation(
                        code: code,
                        listRecordID: record.recordID
                    )

                    // Update local list with cloud record ID
                    await MainActor.run {
                        var updatedList = list
                        updatedList.cloudRecordID = record.recordID.recordName
                        listsViewModel.updateList(updatedList)
                        inviteCode = code
                        isSharing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "Saved locally. CloudKit sync failed: \(error.localizedDescription)"
                    // Still show the code even if CloudKit fails
                    inviteCode = code
                }
            }
        }
    }
}

#Preview {
    ShareListSheet(listID: UUID())
        .environment(ListsViewModel())
        .environment(UserViewModel())
}
