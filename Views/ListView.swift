import SwiftUI

struct ListView: View {
    let listID: UUID

    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel

    @State private var newTaskText = ""
    @State private var showingShareSheet = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var keyboardVisible = false  // driven by UIKit notifications — instant
    @FocusState private var isInputFocused: Bool
    @FocusState private var isTitleFocused: Bool

    // Confetti params — live-updated by ConfettiSettingsView via @AppStorage
    @AppStorage("confetti_num") private var confettiNum: Int = 80
    @AppStorage("confetti_size") private var confettiSize: Double = 11.0
    @AppStorage("confetti_rainHeight") private var confettiRainHeight: Double = 700.0
    @AppStorage("confetti_opacity") private var confettiOpacity: Double = 1.0
    @AppStorage("confetti_fadesOut") private var confettiFadesOut: Bool = true
    @AppStorage("confetti_openingAngle") private var confettiOpeningAngle: Double = 60.0
    @AppStorage("confetti_closingAngle") private var confettiClosingAngle: Double = 120.0
    @AppStorage("confetti_radius") private var confettiRadius: Double = 520.0
    @AppStorage("confetti_repetitions") private var confettiRepetitions: Int = 1
    @AppStorage("confetti_repetitionInterval") private var confettiRepetitionInterval: Double = 1.0
    @AppStorage("confetti_spinSpeed") private var confettiSpinSpeed: Double = 1.0

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
                    // Task list — List is required for swipeActions to work correctly.
                    // When empty, swap in a friendly empty state instead of a blank list.
                    // Tapping anywhere outside the keyboard dismisses it.
                    Group {
                        if list.tasks.isEmpty {
                            emptyTasksView(accentColor: Color(hex: list.color))
                        } else {
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
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .listStyle(.plain)
                            .scrollDismissesKeyboard(.immediately)
                        }
                    }

                    // Add task input
                    HStack(spacing: 12) {
                        TextField("Add a task...", text: $newTaskText)
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .onSubmit { addTask() }

                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
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
                // Tint interactive elements (buttons, checkmarks) with list accent color
                .tint(Color(hex: list.color))
                .navigationBarTitleDisplayMode(.large)
                .navigationTitle(list.name)
                .onTapGesture {
                    if canEditTitle(list) {
                        startEditingTitle(list: list)
                    }
                }
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
                    } else if keyboardVisible {
                        // Notes-style: checkmark appears the moment keyboard shows, tap to dismiss
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                isInputFocused = false
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil
                                )
                            } label: {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                            }
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button(role: .destructive) {
                                    listsViewModel.resetList(listID)
                                } label: {
                                    Label("Reset List", systemImage: "arrow.counterclockwise")
                                }

                                Divider()

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
            } else {
                Text("List not found")
                    .foregroundStyle(.secondary)
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        // Track keyboard visibility via UIKit notifications — more reliable than @FocusState for toolbar
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            guard !isEditingTitle else { return }
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .confettiCannon(
            trigger: Binding(
                get: { listsViewModel.confettiTrigger },
                set: { _ in }
            ),
            num: confettiNum,
            colors: [.kaiPurple, .kaiRed, .kaiTeal, .kaiYellow, .kaiOrange, .kaiMint, .kaiPink, .kaiBlue],
            confettiSize: CGFloat(confettiSize),
            rainHeight: CGFloat(confettiRainHeight),
            fadesOut: confettiFadesOut,
            opacity: confettiOpacity,
            openingAngle: .degrees(confettiOpeningAngle),
            closingAngle: .degrees(confettiClosingAngle),
            radius: CGFloat(confettiRadius),
            repetitions: confettiRepetitions,
            repetitionInterval: confettiRepetitionInterval,
            spinSpeedMultiplier: confettiSpinSpeed
        )
        .overlay {
            if listsViewModel.listCompletedTrigger > 0 {
                MultiFireworkOverlay(trigger: listsViewModel.listCompletedTrigger)
            }
        }
    }

    // MARK: - Empty State

    /// Shown when the list has no tasks yet — centered, friendly, uses the list's accent color.
    @ViewBuilder
    private func emptyTasksView(accentColor: Color) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text("📝")
                .font(.system(size: 56))

            Text("No tasks yet!")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Add one below 👇")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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

// MARK: - Multi-Firework Overlay

/// Fires 5 staggered 360° confetti cannons (4 corners + center) when an entire list is completed.
struct MultiFireworkOverlay: View {
    let trigger: Int
    @State private var t1 = 1; @State private var t2 = 1
    @State private var t3 = 1; @State private var t4 = 1; @State private var t5 = 1

    var body: some View {
        ZStack {
            // Center burst
            ConfettiCannon(trigger: $t5, num: 80, openingAngle: .degrees(0), closingAngle: .degrees(360), radius: 300)
            VStack {
                HStack {
                    ConfettiCannon(trigger: $t1, num: 20, openingAngle: .degrees(0), closingAngle: .degrees(360), radius: 200)
                    Spacer()
                    ConfettiCannon(trigger: $t2, num: 20, openingAngle: .degrees(0), closingAngle: .degrees(360), radius: 200)
                }
                Spacer()
                HStack {
                    ConfettiCannon(trigger: $t3, num: 20, openingAngle: .degrees(0), closingAngle: .degrees(360), radius: 200)
                    Spacer()
                    ConfettiCannon(trigger: $t4, num: 20, openingAngle: .degrees(0), closingAngle: .degrees(360), radius: 200)
                }
            }
        }
        .onAppear {
            t1 += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { t4 += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { t2 += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { t3 += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { t5 += 1 }
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
