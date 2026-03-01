import SwiftUI

struct HomeView: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel

    @State private var showingNewListSheet = false
    @State private var showingJoinSheet = false
    @State private var showingProgressSheet = false
    @State private var showingSettings = false
    @State private var showingCloudKitSetup = false
    @State private var cloudKitSetupMessage: String?
    @State private var isInitializingSchema = false

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
                                NavigationLink(value: list) {
                                    ListCard(list: list)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        listsViewModel.deleteList(list)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 100) // room for floating button
                    }
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
            .navigationTitle("Kai To Do ✅")
            .navigationDestination(for: TodoList.self) { list in
                ListView(listID: list.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingJoinSheet = true
                        } label: {
                            Label("Join List", systemImage: "person.badge.plus")
                        }

                        Button {
                            showingProgressSheet = true
                        } label: {
                            Label("Family Progress", systemImage: "chart.bar.fill")
                        }

                        Divider()

                        Button {
                            initializeCloudKitSchema()
                        } label: {
                            Label("Setup CloudKit Schema", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(isInitializingSchema)
                    } label: {
                        if isInitializingSchema {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.kaiPurple)
                    }
                }
            }
            .sheet(isPresented: $showingNewListSheet) {
                NewListSheet()
            }
            .sheet(isPresented: $showingJoinSheet) {
                JoinListSheet()
            }
            .sheet(isPresented: $showingProgressSheet) {
                FamilyProgressSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    showingJoinSheet: $showingJoinSheet,
                    showingProgressSheet: $showingProgressSheet
                )
            }
            .alert("CloudKit Setup", isPresented: $showingCloudKitSetup) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(cloudKitSetupMessage ?? "")
            }
        }
    }

    private func initializeCloudKitSchema() {
        isInitializingSchema = true

        Task {
            do {
                // Check iCloud account status first
                let status = try await CloudKitService.shared.checkAccountStatus()

                guard status == .available else {
                    await MainActor.run {
                        isInitializingSchema = false
                        cloudKitSetupMessage = "iCloud account not available. Please sign in to iCloud in Settings."
                        showingCloudKitSetup = true
                    }
                    return
                }

                // Initialize the schema
                try await CloudKitService.shared.initializeSchema()

                await MainActor.run {
                    isInitializingSchema = false
                    cloudKitSetupMessage = "CloudKit schema created successfully! You can now see the record types in CloudKit Dashboard."
                    showingCloudKitSetup = true
                }
            } catch {
                await MainActor.run {
                    isInitializingSchema = false
                    cloudKitSetupMessage = "Failed to initialize schema: \(error.localizedDescription)"
                    showingCloudKitSetup = true
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("✅")
                .font(.system(size: 64))

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

// MARK: - New List Sheet

struct NewListSheet: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedColorIndex = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("List Name") {
                    TextField("Enter list name", text: $name)
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
    }
}

#Preview {
    HomeView()
        .environment(ListsViewModel())
        .environment(UserViewModel())
}
