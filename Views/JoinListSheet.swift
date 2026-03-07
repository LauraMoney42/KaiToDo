import SwiftUI
import CloudKit

struct JoinListSheet: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel
    @Environment(\.dismiss) private var dismiss

    /// Optional prefill from deep link (kaitodo://join/CODE) — auto-triggers join on appear
    var prefillCode: String? = nil

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
                        .foregroundStyle(Color.kaiTeal)

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
                if let code = prefillCode {
                    // Deep link: prefill code and auto-join immediately
                    inviteCode = code
                    joinList()
                } else {
                    isTextFieldFocused = true
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func joinList() {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                // Look up the invitation record by invite code (always in public DB)
                guard let invitation = try await CloudKitService.shared.findInvitation(byCode: inviteCode) else {
                    await MainActor.run {
                        isJoining = false
                        errorMessage = "No list found with that code. Please check and try again."
                    }
                    return
                }

                // Check if the invitation has been migrated to CKShare (Phase 2)
                let isMigrated = (invitation["migratedToPrivateDB"] as? Int64 ?? 0) == 1
                let shareURLString = invitation["shareURL"] as? String
                let zoneName = invitation["zoneName"] as? String
                let zoneOwnerName = invitation["zoneOwnerName"] as? String

                if isMigrated, let urlString = shareURLString, let shareURL = URL(string: urlString),
                   let zoneName, let zoneOwnerName {
                    // Phase 2 path: accept CKShare, then fetch from shared DB
                    try await CloudKitService.shared.acceptShare(url: shareURL)

                    // Brief pause to let CloudKit propagate the accepted share
                    try await Task.sleep(nanoseconds: 1_000_000_000)

                    let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwnerName)

                    // Retry fetching tasks (zone may take a moment to appear after acceptance)
                    var tasks: [TodoTask] = []
                    var fetchError: Error?
                    for attempt in 1...3 {
                        do {
                            tasks = try await CloudKitService.shared.fetchTasksInZone(zoneID)
                            fetchError = nil
                            break
                        } catch {
                            fetchError = error
                            if attempt < 3 {
                                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                            }
                        }
                    }
                    if let fetchError { throw fetchError }

                    // Fetch the SharedList record from the shared zone to get metadata
                    let db = CloudKitService.shared.database(for: zoneID)
                    let query = CKQuery(recordType: "SharedList", predicate: NSPredicate(value: true))
                    let (results, _) = try await db.records(matching: query, inZoneWith: zoneID)
                    var listRecord: CKRecord?
                    for (_, result) in results {
                        if case .success(let record) = result {
                            listRecord = record
                            break
                        }
                    }

                    let record = listRecord
                    let sharedList = TodoList(
                        name: record?["name"] as? String ?? "Shared List",
                        color: record?["color"] as? String ?? "7161EF",
                        tasks: tasks,
                        cloudRecordID: record?.recordID.recordName,
                        isShared: true,
                        shareType: .participant,
                        ownerID: record?["ownerID"] as? String,
                        ownerName: record?["ownerName"] as? String,
                        inviteCode: inviteCode,
                        zoneID: zoneName,
                        zoneOwnerName: zoneOwnerName,
                        isMigratedToPrivateDB: true,
                        starCount: (record?["starCount"] as? Int64).map(Int.init) ?? 0,
                        starGoal: (record?["starGoal"] as? Int64).map(Int.init),
                        rewardText: record?["rewardText"] as? String,
                        rewardGiven: (record?["rewardGiven"] as? Int64 ?? 0) == 1
                    )

                    await MainActor.run {
                        if !listsViewModel.lists.contains(where: { $0.zoneID == zoneName }) {
                            listsViewModel.lists.append(sharedList)
                            listsViewModel.saveLists()
                        }
                        isJoining = false
                        dismiss()
                    }
                } else {
                    // Legacy path: fetch from public DB (pre-migration lists)
                    if let (record, tasks) = try await CloudKitService.shared.fetchSharedList(byInviteCode: inviteCode) {
                        let sharedList = TodoList(
                            name: record["name"] as? String ?? "Shared List",
                            color: record["color"] as? String ?? "7161EF",
                            tasks: tasks,
                            cloudRecordID: record.recordID.recordName,
                            isShared: true,
                            shareType: .participant,
                            ownerID: record["ownerID"] as? String,
                            ownerName: record["ownerName"] as? String,
                            inviteCode: inviteCode,
                            starCount: (record["starCount"] as? Int64).map(Int.init) ?? 0,
                            starGoal: (record["starGoal"] as? Int64).map(Int.init),
                            rewardText: record["rewardText"] as? String,
                            rewardGiven: (record["rewardGiven"] as? Int64 ?? 0) == 1
                        )

                        // Try to register as participant (non-fatal)
                        try? await CloudKitService.shared.addParticipant(
                            userID: userViewModel.userID,
                            userName: userViewModel.nickname,
                            toListRecord: record
                        )

                        await MainActor.run {
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
