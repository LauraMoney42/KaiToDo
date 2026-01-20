import SwiftUI

struct ListView: View {
    let listID: UUID

    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel

    @State private var newTaskText = ""
    @State private var showingShareSheet = false
    @FocusState private var isInputFocused: Bool

    private var list: TodoList? {
        listsViewModel.getList(by: listID)
    }

    var body: some View {
        ZStack {
            if let list = list {
                VStack(spacing: 0) {
                    // Task list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(list.tasks) { task in
                                TaskRow(
                                    task: task,
                                    accentColor: Color(hex: list.color),
                                    onToggle: {
                                        listsViewModel.toggleTaskWithSync(
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
                                Divider()
                            }
                        }
                    }

                    // Add task input
                    HStack(spacing: 12) {
                        TextField("Add a task...", text: $newTaskText)
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .onSubmit {
                                addTask()
                            }

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
                .navigationTitle(list.name)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if list.isShared {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                refreshList()
                            } label: {
                                if listsViewModel.isSyncing {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                            .disabled(listsViewModel.isSyncing)
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
                                    refreshList()
                                } label: {
                                    Label("Refresh from Cloud", systemImage: "arrow.clockwise")
                                }

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

    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listsViewModel.addTaskWithSync(to: listID, text: trimmed)
        newTaskText = ""
    }

    private func refreshList() {
        Task {
            await listsViewModel.syncSharedLists()
        }
    }
}

#Preview {
    NavigationStack {
        ListView(listID: UUID())
            .environment(ListsViewModel())
            .environment(UserViewModel())
    }
}
