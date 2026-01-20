import SwiftUI

struct HomeView: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(UserViewModel.self) private var userViewModel

    @State private var showingNewListSheet = false
    @State private var showingJoinSheet = false
    @State private var showingProgressSheet = false
    @State private var selectedList: TodoList?
    @State private var showingCloudKitSetup = false
    @State private var cloudKitSetupMessage: String?
    @State private var isInitializingSchema = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
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
                }
            }
            .navigationTitle("KaiToDo")
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
                        showingNewListSheet = true
                    } label: {
                        Image(systemName: "plus")
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

            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Lists Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to create your first list")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

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
                    Button("Cancel") {
                        dismiss()
                    }
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
