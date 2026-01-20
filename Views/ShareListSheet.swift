import SwiftUI

struct ShareListSheet: View {
    let listID: UUID

    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var inviteCode: String?
    @State private var copied = false

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
                    Button {
                        shareList()
                    } label: {
                        Label("Generate Invite Code", systemImage: "link")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.kaiPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
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
        guard let code = listsViewModel.shareList(
            listID,
            ownerID: userViewModel.userID,
            ownerName: userViewModel.nickname
        ) else { return }
        inviteCode = code
    }
}

#Preview {
    ShareListSheet(listID: UUID())
        .environment(ListsViewModel())
        .environment(UserViewModel())
}
