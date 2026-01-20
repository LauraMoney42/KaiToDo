import SwiftUI

struct FamilyProgressSheet: View {
    @Environment(ListsViewModel.self) private var listsViewModel
    @Environment(\.dismiss) private var dismiss

    private var sharedLists: [TodoList] {
        listsViewModel.lists.filter { $0.isShared }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall stats
                    VStack(spacing: 8) {
                        Text("\(listsViewModel.totalCompletedTasks())")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.kaiPurple)

                        Text("Tasks Completed")
                            .foregroundStyle(.secondary)

                        if listsViewModel.totalTasks() > 0 {
                            Text("out of \(listsViewModel.totalTasks()) total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Shared lists progress
                    if !sharedLists.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Shared Lists")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(sharedLists) { list in
                                ListProgressCard(list: list)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)

                            Text("No shared lists yet")
                                .foregroundStyle(.secondary)

                            Text("Share a list to track family progress")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    // All lists
                    if !listsViewModel.lists.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("All Lists")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(listsViewModel.lists) { list in
                                ListProgressCard(list: list)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Family Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ListProgressCard: View {
    let list: TodoList
    @Environment(ListsViewModel.self) private var listsViewModel

    private var participantStats: [String: Int] {
        listsViewModel.participantStats(for: list.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color(hex: list.color))
                    .frame(width: 12, height: 12)

                Text(list.name)
                    .fontWeight(.medium)

                Spacer()

                Text("\(list.completedTaskCount)/\(list.totalTaskCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: list.color))
                        .frame(width: geometry.size.width * list.completionProgress, height: 8)
                }
            }
            .frame(height: 8)

            // Participant stats
            if !participantStats.isEmpty {
                HStack(spacing: 16) {
                    ForEach(participantStats.sorted(by: { $0.value > $1.value }), id: \.key) { name, count in
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Text("\(name): \(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .padding(.horizontal)
    }
}

#Preview {
    FamilyProgressSheet()
        .environment(ListsViewModel())
}
