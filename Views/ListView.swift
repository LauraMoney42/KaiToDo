import SwiftUI

struct ListView: View {
    let listID: UUID

    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel

    @State private var newTaskText = ""
    @State private var showingShareSheet = false
    @State private var showingStarGoalSheet = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var keyboardVisible = false      // driven by UIKit notifications — instant
    @State private var seenCompletedTrigger = 0    // snapshot on appear — only fire confetti on NEW completions
    @FocusState private var isInputFocused: Bool
    @FocusState private var isTitleFocused: Bool

    // Confetti params are intentionally NOT stored here — see ConfettiCannonView below.
    // Previously, 11 @AppStorage properties here caused ListView to re-render the entire
    // task list whenever any confetti setting changed. They now live in a child view so
    // settings changes only re-render that isolated overlay.

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
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                }
                                .onMove { source, destination in
                                    listsViewModel.moveTask(in: listID, from: source, to: destination)
                                }
                            }
                            .listStyle(.plain)
                            .scrollDismissesKeyboard(.immediately)
                            // Keep editMode inactive — drag-to-reorder works via long-press without visible handles
                            .environment(\.editMode, .constant(.inactive))
                        }
                    }

                    // Add task input — contentShape + onTapGesture makes the ENTIRE bar tappable,
                    // not just the exact TextField bounds, so a tap anywhere in the row focuses input.
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
                    .contentShape(Rectangle())
                    // simultaneousGesture — allows the focus tap to fire WITHOUT blocking the
                    // "+" button or TextField. Previously .onTapGesture added ~300ms disambiguation
                    // delay because SwiftUI waited to see if the tap was for this gesture or a child.
                    .simultaneousGesture(TapGesture().onEnded { isInputFocused = true })
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
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("") // title rendered in .principal slot below
                .toolbar {
                    // Title — always in .principal so long-press gesture is always reachable.
                    // Long-press (≥0.5s) triggers inline rename for list owners/local lists.
                    // Switches to a focused TextField; confirm via Return or "Done" button.
                    ToolbarItem(placement: .principal) {
                        if isEditingTitle {
                            TextField("List name", text: $editedTitle)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .focused($isTitleFocused)
                                .onSubmit { commitTitleEdit(list: list) }
                                .submitLabel(.done)
                        } else {
                            Text(list.name)
                                .font(.headline)
                                .lineLimit(1)
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    guard canEditTitle(list) else { return }
                                    startEditingTitle(list: list)
                                }
                        }
                    }

                    if isEditingTitle {
                        // Confirm rename
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { commitTitleEdit(list: list) }
                                .fontWeight(.semibold)
                        }
                    } else {
                        // Sync button — only for shared lists
                        if list.isShared {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { refreshList() } label: {
                                    if listsViewModel.isSyncing {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .disabled(listsViewModel.isSyncing)
                            }
                        }

                        // Keyboard dismiss — kept SEPARATE from the … menu so the menu is
                        // never swapped out of the toolbar (iOS drops the first tap on a
                        // Menu that just appeared in a slot).
                        if keyboardVisible {
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
                        }

                        // … menu — always present so iOS never re-renders this slot.
                        // "Rename List" removed — long-press on the title replaces it.
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                if canEditTitle(list) {
                                    Button {
                                        showingStarGoalSheet = true
                                    } label: {
                                        Label("Set Star Goal", systemImage: "star.fill")
                                    }

                                    Divider()
                                }

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
                }
                .sheet(isPresented: $showingShareSheet) {
                    ShareListSheet(listID: listID)
                }
                .sheet(isPresented: $showingStarGoalSheet) {
                    StarGoalSheet(listID: listID)
                }
            } else {
                Text("List not found")
                    .foregroundStyle(.secondary)
            }
        }
        // NOTE: Outer tap gesture removed — was competing with inner title-edit tap and List row taps,
        // causing gesture disambiguation delay (perceived as "unresponsive"). Keyboard dismiss is
        // handled by: toolbar checkmark (keyboardVisible=true), scrollDismissesKeyboard(.immediately).
        // Track keyboard visibility via UIKit notifications — more reliable than @FocusState for toolbar
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            guard !isEditingTitle else { return }
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        // ConfettiCannonLayer owns all @AppStorage params — isolated so confetti
        // setting changes never re-render the ListView task list.
        .overlay {
            ConfettiCannonLayer(trigger: listsViewModel.confettiTrigger)
                .allowsHitTesting(false)
        }
        .overlay {
            // Only fire when trigger increments AFTER this view appeared —
            // prevents premade/already-complete lists from firing on open
            if listsViewModel.listCompletedTrigger > seenCompletedTrigger {
                MultiFireworkOverlay(trigger: listsViewModel.listCompletedTrigger)
            }
        }
        .overlay {
            // ⭐ Gold Star celebration — layered over confetti, non-blocking
            if listsViewModel.listCompletedTrigger > seenCompletedTrigger {
                GoldStarCelebrationOverlay(trigger: listsViewModel.listCompletedTrigger)
            }
        }
        .onAppear {
            // Snapshot current trigger so pre-existing completions don't fire
            seenCompletedTrigger = listsViewModel.listCompletedTrigger
            // Auto-sync shared lists on open — pulls latest tasks from CloudKit
            // so participant changes are visible immediately without manual refresh.
            if let list = list, list.isShared {
                Task { await listsViewModel.syncSharedLists() }
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
        listsViewModel.addTaskWithSync(to: listID, text: trimmed)
        newTaskText = ""
    }

    private func refreshList() {
        Task {
            await listsViewModel.syncSharedLists()
        }
    }
}

// MARK: - Confetti Cannon Layer

/// Isolated confetti view — owns its @AppStorage params so changes don't re-render ListView body.
private struct ConfettiCannonLayer: View {
    let trigger: Int

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

    var body: some View {
        Color.clear
            .confettiCannon(
                trigger: Binding(get: { trigger }, set: { _ in }),
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

// MARK: - Gold Star Celebration Overlay

/// Large ⭐ reward moment — springs in, glows, fades out in ~2s alongside multi-confetti.
/// Non-blocking: allowsHitTesting(false) so users can still interact beneath it.
struct GoldStarCelebrationOverlay: View {
    let trigger: Int

    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var shimmerPhase: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Soft radial glow behind the star
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "FFD84D").opacity(0.55),
                            Color(hex: "FFB800").opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: glowRadius
                    )
                )
                .frame(width: glowRadius * 2, height: glowRadius * 2)
                .opacity(opacity)

            // The star itself — spins during celebration
            Text("⭐")
                .font(.system(size: 120))
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .opacity(opacity)
                // Shimmer: subtle brightness pulse
                .brightness(shimmerPhase * 0.25)
        }
        .allowsHitTesting(false)
        .onAppear {
            runAnimation()
        }
    }

    private func runAnimation() {
        // Phase 1 — spring pop in + start spin (0–0.5s)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            scale = 1.2
            opacity = 1.0
            glowRadius = 160
        }
        // Spin: += 360 so re-triggers always animate a full turn from current value.
        // Setting rotation = 360 is a no-op when state is already at 360 (common on
        // second+ list completion), causing the star to appear frozen.
        withAnimation(.easeInOut(duration: 1.4)) {
            rotation += 360
        }
        // Phase 2 — settle to natural size (0.45s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }
        // Phase 3 — shimmer pulse (0.5–1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.35)) {
                shimmerPhase = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    shimmerPhase = 0.0
                }
            }
        }
        // Phase 4 — fade out (1.3–1.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 0
                scale = 1.1
                glowRadius = 0
            }
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
