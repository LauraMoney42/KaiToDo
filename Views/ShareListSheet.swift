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
                        .foregroundStyle(Color.kaiPurple)

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
                            .foregroundStyle(Color.kaiPurple)
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

                // Share button — uses UIActivityViewController instead of ShareLink so we
                // get completionWithItemsHandler and can auto-dismiss this sheet after sending.
                // ShareLink has no completion callback, so the sheet stayed open after Messages send.
                if let code = inviteCode ?? list?.inviteCode {
                    let shareText = "Join my KaiToDo list \"\(list?.name ?? "")\" — tap to open: kaitodo://join/\(code)"
                    Button {
                        presentShareSheet(text: shareText)
                    } label: {
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

    /// Present UIActivityViewController so we get a completion callback.
    /// Dismisses ShareListSheet automatically when the user completes a share action
    /// (e.g. sends via Messages). ShareLink has no completion handler so it left the
    /// sheet open — this was the root cause of the bug.
    private func presentShareSheet(text: String) {
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            // Only dismiss when user actually completed a share — not on cancel
            if completed {
                dismiss()
            }
        }
        // Traverse to the topmost presented view controller to avoid "already presenting" crash
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(activityVC, animated: true)
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

        // Save to CloudKit using CKShare + Private DB (Phase 2)
        Task {
            do {
                guard var list = listsViewModel.getList(by: listID) else { return }

                // 1. Create a custom zone for this list
                let zoneName = "KaiList-\(list.id.uuidString)"
                let zone = try await CloudKitService.shared.createZone(named: zoneName)

                // 2. Save SharedList record into the zone
                let record = try await CloudKitService.shared.saveSharedListInZone(
                    list,
                    ownerID: userViewModel.userID,
                    ownerName: userViewModel.nickname,
                    zoneID: zone.zoneID
                )

                // 3. Save all existing tasks into the zone
                var taskRecordIDs: [UUID: String] = [:]
                for task in list.tasks {
                    let taskRecord = try await CloudKitService.shared.saveTaskInZone(
                        task, listRecordID: record.recordID, zoneID: zone.zoneID
                    )
                    taskRecordIDs[task.id] = taskRecord.recordID.recordName
                }

                // 4. Create CKShare for the zone (readWrite for anyone with link)
                let share = try await CloudKitService.shared.createZoneShare(in: zone.zoneID)

                // 5. Create invitation in PUBLIC DB with zone metadata (no cross-DB reference)
                if let shareURL = share.url {
                    _ = try await CloudKitService.shared.createInvitationForZone(
                        code: code,
                        shareURL: shareURL.absoluteString,
                        zoneName: zoneName,
                        zoneOwnerName: zone.zoneID.ownerName
                    )
                }

                // 7. Update local list with zone metadata
                await MainActor.run {
                    list.cloudRecordID = record.recordID.recordName
                    list.zoneID = zoneName
                    list.zoneOwnerName = zone.zoneID.ownerName
                    list.shareRecordName = share.recordID.recordName
                    list.shareURL = share.url?.absoluteString
                    list.isMigratedToPrivateDB = true
                    for i in list.tasks.indices {
                        list.tasks[i].cloudRecordID = taskRecordIDs[list.tasks[i].id]
                    }
                    listsViewModel.updateList(list)
                    inviteCode = code
                    isSharing = false
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "Saved locally. CloudKit sync failed: \(error.localizedDescription)"
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
