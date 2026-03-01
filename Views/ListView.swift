import SwiftUI

struct ListView: View {
    let listID: UUID

    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel

    @State private var newTaskText = ""
    @State private var showingShareSheet = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isInputFocused: Bool
    @FocusState private var isTitleFocused: Bool

    private var list: TodoList? {
        listsViewModel.getList(by: listID)
    }

    /// User can edit if list is local, or if they are the owner
    private func canEditTitle(_ list: TodoList) -> Bool {
        list.shareType == .local || list.ownerID == userViewModel.userID
    }

    var body: some View {
        ZStack {
            if let list = list {
                VStack(spacing: 0) {
                    // Task list — List is required for swipeActions to work correctly
                    List {
                        ForEach(list.tasks) { task in
                            TaskRow(
                                task: task,
                                accentColor: Color(hex: list.color),
                                onToggle: {
                                    listsViewModel.toggleTask(
                                        in: listID,
                                        taskID: task.id,
                                        userID: userViewModel.userID,
                                        userName: userViewModel.nickname
                                    )
                                },
                                onDelete: {
                                    listsViewModel.deleteTask(in: listID, taskID: task.id)
                                }
                            )
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(.plain)

                    // Add task input
                    HStack(spacing: 12) {
                        TextField("Add a task...", text: $newTaskText)
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .onSubmit { addTask() }

                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color(hex: list.color))
                        }
                        .disabled(newTaskText.isEmpty)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 0.5),
                        alignment: .top
                    )
                }
                .navigationBarTitleDisplayMode(.large)
                .navigationTitle(isEditingTitle ? "" : list.name)
                .toolbar {
                    // Inline title editor (principal placement = center of nav bar)
                    if isEditingTitle {
                        ToolbarItem(placement: .principal) {
                            TextField("List name", text: $editedTitle)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .focused($isTitleFocused)
                                .onSubmit { commitTitleEdit(list: list) }
                                .submitLabel(.done)
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { commitTitleEdit(list: list) }
                                .fontWeight(.semibold)
                        }
                    } else {
                        // Tappable title hint (only for owner)
                        if canEditTitle(list) {
                            ToolbarItem(placement: .principal) {
                                Button {
                                    startEditingTitle(list: list)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(list.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button {
                                    showingShareSheet = true
                                } label: {
                                    Label("Share List", systemImage: "square.and.arrow.up")
                                }

                                if list.isShared {
                                    Button {
                                        // Show participants
                                    } label: {
                                        Label("Participants (\(list.participants.count + 1))", systemImage: "person.2")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    ShareListSheet(listID: listID)
                }

                // Confetti overlay
                if listsViewModel.showingConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            } else {
                Text("List not found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startEditingTitle(list: TodoList) {
        editedTitle = list.name
        isEditingTitle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isTitleFocused = true
        }
    }

    private func commitTitleEdit(list: TodoList) {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != list.name {
            listsViewModel.updateListName(listID: listID, name: trimmed)
        }
        isEditingTitle = false
        isTitleFocused = false
    }

    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listsViewModel.addTask(to: listID, text: trimmed)
        newTaskText = ""
    }
}

#Preview {
    NavigationStack {
        ListView(listID: UUID())
            .environment(ListsViewModel())
            .environment(UserViewModel())
    }
}
