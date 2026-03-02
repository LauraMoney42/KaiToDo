import SwiftUI

struct HomeView: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel

    @State private var showingNewListSheet = false
    @State private var showingSettings = false
    @State private var showingStarBreakdown = false
    @State private var draggingList: TodoList?

    // ⭐ Gold Star counter
    @State private var flyingStarVisible = false  // triggers fly-up animation on star earned
    @State private var flyingStarOffset: CGFloat = 0

    private var totalStars: Int {
        listsViewModel.lists.reduce(0) { $0 + $1.starCount }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    if listsViewModel.lists.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(listsViewModel.lists) { list in
                                // NavigationLink wraps ListCard directly — tap reliably opens the list.
                                // .buttonStyle(.plain) suppresses NavigationLink's default blue highlight.
                                // .draggable uses long-press so it doesn't conflict with a normal tap.
                                NavigationLink(value: list) {
                                    let isDragged = draggingList?.id == list.id
                                    ListCard(list: list)
                                        .opacity(isDragged ? 0.5 : 1.0)
                                        .scaleEffect(isDragged ? 0.95 : 1.0)
                                        // Only animate the card actually being dragged — previously ALL cards
                                        // evaluated this animation on every draggingList change, causing
                                        // unnecessary layout passes and frame drops during scroll.
                                        .animation(isDragged ? .easeInOut(duration: 0.2) : nil, value: draggingList?.id)
                                }
                                .buttonStyle(.plain)
                                // Drag source — long-press lifts the card
                                .draggable(list) {
                                    ListCard(list: list)
                                        .frame(width: 160)
                                        .opacity(0.85)
                                        .onAppear { draggingList = list }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        listsViewModel.deleteList(list)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                // Drop target — reorder when another card is dropped here
                                .dropDestination(for: TodoList.self) { items, _ in
                                    guard let dropped = items.first else { return false }
                                    listsViewModel.reorderList(moving: dropped, before: list)
                                    draggingList = nil
                                    return true
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 100) // room for floating button
                    }
                }
                // Custom nav header via safeAreaInset — pure SwiftUI, zero UIKit involvement.
                // This completely replaces .toolbar{} which routes through UIBarButtonItem/UIKit
                // and renders circular backgrounds on iOS 17+ regardless of appearance overrides.
                .safeAreaInset(edge: .top, spacing: 0) {
                    customNavHeader
                }

                // Floating + button at bottom center
                Button {
                    showingNewListSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.kaiPurple)
                        .clipShape(Circle())
                        .shadow(color: Color.kaiPurple.opacity(0.45), radius: 14, y: 5)
                }
                .padding(.bottom, 32)
            }
            // Hide UIKit nav bar entirely — our custom header replaces it.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TodoList.self) { list in
                ListView(listID: list.id)
            }
            // Flying ⭐ animation — rises from bottom center toward the star counter
            .overlay(alignment: .bottom) {
                if flyingStarVisible {
                    Text("⭐")
                        .font(.system(size: 32))
                        .offset(y: flyingStarOffset)
                        .opacity(flyingStarVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.6), value: flyingStarOffset)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .starEarned)) { _ in
                flyingStarOffset = 0
                flyingStarVisible = true
                withAnimation(.easeOut(duration: 0.55)) {
                    flyingStarOffset = -200
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    flyingStarVisible = false
                    flyingStarOffset = 0
                }
            }
            .sheet(isPresented: $showingNewListSheet) {
                NewListSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingStarBreakdown) {
                StarBreakdownSheet()
            }
        }
    }

    /// Pure SwiftUI nav header — replaces UIKit toolbar to eliminate iOS 17 circular button backgrounds.
    /// safeAreaInset places this above the scroll view and adjusts its content inset automatically.
    private var customNavHeader: some View {
        HStack {
            // ⭐ Star counter — left
            Button {
                showingStarBreakdown = true
            } label: {
                ZStack {
                    Text("⭐")
                        .font(.system(size: 44))
                    Text("\(totalStars)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 1.5, x: 0, y: 1)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // App title — center
            Text("Kai To Do")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            // ⚙️ Settings — right
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.kaiPurple)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar) // matches system nav bar material
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("No Lists Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the ＋ button to create your first list")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .padding(.top, 80)
    }
}

// MARK: - Star Breakdown Sheet

/// Shows per-list star counts — opened by tapping the ⭐ counter in HomeView toolbar.
struct StarBreakdownSheet: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let listsWithStars = listsViewModel.lists.filter { $0.starCount > 0 }
                if listsWithStars.isEmpty {
                    ContentUnavailableView(
                        "No Stars Yet",
                        systemImage: "star",
                        description: Text("Complete a whole list to earn your first ⭐")
                    )
                } else {
                    ForEach(listsWithStars) { list in
                        if let goal = list.starGoal {
                            // Full progress card + "Mark reward given" when goal met
                            VStack(alignment: .leading, spacing: 8) {
                                StarProgressCard(list: list, goal: goal)
                                    .padding(.vertical, 2)

                                // Show button when goal reached and reward not yet given
                                if list.starCount >= goal && !list.rewardGiven {
                                    Button {
                                        listsViewModel.markRewardGiven(listID: list.id)
                                    } label: {
                                        Label("Mark reward given", systemImage: "checkmark.seal.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color(hex: "34d399"))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                } else if list.rewardGiven {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                        Text("Reward given ✓")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(Color(hex: "34d399"))
                                }
                            }
                        } else {
                            HStack {
                                Circle()
                                    .fill(Color(hex: list.color))
                                    .frame(width: 12, height: 12)
                                Text(list.name)
                                    .font(.body)
                                Spacer()
                                Text(String(format: NSLocalizedString("%lld ⭐", comment: "Star count for a list"), list.starCount))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "FFB800"))
                            }
                        }
                    }
                }
            }
            .navigationTitle("⭐ Stars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Star Goal Sheet

/// Lets the list creator set a ⭐ goal + reward for a specific list.
/// Opened from the ListView … menu → "Set Star Goal".
struct StarGoalSheet: View {
    let listID: UUID

    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(\.dismiss) private var dismiss

    // Local draft state — committed on Save
    @State private var goalEnabled: Bool = false
    @State private var goalCount: Int = 5
    @State private var rewardText: String = ""

    private var list: TodoList? {
        listsViewModel.getList(by: listID)
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Progress card — shown when a goal is already set
                if let list, let goal = list.starGoal {
                    Section {
                        StarProgressCard(list: list, goal: goal)
                    }
                }

                // MARK: Goal toggle + picker
                Section {
                    Toggle(isOn: $goalEnabled) {
                        Label("Set a Star Goal", systemImage: "star.fill")
                            .foregroundStyle(Color(hex: "FFB800"))
                    }
                    .tint(Color(hex: "FFB800"))

                    if goalEnabled {
                        Stepper(value: $goalCount, in: 1...50) {
                            HStack {
                                Text("Goal")
                                Spacer()
                                Text(String(format: NSLocalizedString("%lld ⭐", comment: "Star count for a list"), goalCount))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "FFB800"))
                            }
                        }
                    }
                } footer: {
                    if goalEnabled {
                        // Singular/plural handled via two keys — avoids stringsdict complexity.
                        let earnKey = goalCount == 1
                            ? NSLocalizedString("Earn %lld ⭐ completing the list once to unlock the reward.", comment: "Star goal footer — singular")
                            : NSLocalizedString("Earn %lld ⭐ by completing the list %lld times to unlock the reward.", comment: "Star goal footer — plural")
                        Text(goalCount == 1
                            ? String(format: earnKey, goalCount)
                            : String(format: earnKey, goalCount, goalCount))
                            .font(.caption)
                    }
                }

                // MARK: Reward description
                if goalEnabled {
                    Section("Reward") {
                        TextField("e.g. 🍕 Pizza night!", text: $rewardText)
                            .submitLabel(.done)
                    }
                }
            }
            .navigationTitle("⭐ Star Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        listsViewModel.updateStarGoal(
                            listID: listID,
                            goal: goalEnabled ? goalCount : nil,
                            rewardText: goalEnabled ? rewardText : nil
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Pre-populate with existing values if already set
                if let list, let goal = list.starGoal {
                    goalEnabled = true
                    goalCount = goal
                    rewardText = list.rewardText ?? ""
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Star Progress Card

/// Progress bar + reward text — shown inside StarGoalSheet and StarBreakdownSheet.
struct StarProgressCard: View {
    let list: TodoList
    let goal: Int

    private var progress: Double {
        min(Double(list.starCount) / Double(goal), 1.0)
    }

    private var isComplete: Bool {
        list.starCount >= goal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(list.name)
                    .font(.headline)
                Spacer()
                Text(String(format: NSLocalizedString("%lld / %lld ⭐", comment: "Star progress: earned / goal"), list.starCount, goal))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isComplete ? Color(hex: "34d399") : Color(hex: "FFB800"))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "FFB800").opacity(0.18))
                        .frame(height: 10)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isComplete
                                    ? [Color(hex: "34d399"), Color(hex: "a7f3d0")]
                                    : [Color(hex: "FFB800"), Color(hex: "FFD84D")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 10)

            // Reward label
            if let reward = list.rewardText, !reward.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: isComplete ? "gift.fill" : "gift")
                        .font(.caption)
                        .foregroundStyle(isComplete ? Color(hex: "34d399") : .secondary)
                    Text(String(format: NSLocalizedString(isComplete ? "Reward unlocked: %@" : "Reward: %@", comment: "Reward label in progress card"), reward))
                        .font(.caption)
                        .foregroundStyle(isComplete ? Color(hex: "34d399") : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New List Sheet

struct NewListSheet: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedColorIndex = 0
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("List Name") {
                    TextField("Enter list name", text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(0..<Color.listColors.count, id: \.self) { index in
                            Circle()
                                .fill(Color.listColors[index])
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 3 : 0)
                                        .padding(2)
                                )
                                .onTapGesture {
                                    selectedColorIndex = index
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let _ = listsViewModel.createList(
                            name: name.isEmpty ? "New List" : name,
                            color: Color.listColorHexes[selectedColorIndex]
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            // Auto-focus on appear — sheet's drag gesture eats the first tap at .medium detent,
            // so focusing programmatically means the user never needs to tap at all.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isNameFocused = true
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(ListsViewModel())
        .environment(UserViewModel())
}
