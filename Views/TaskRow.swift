import SwiftUI

struct TaskRow: View {
    let task: TodoTask
    let accentColor: Color
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showingDeleteButton = false

    var body: some View {
        ZStack {
            // Delete background
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                }
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }

            // Main content
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .stroke(task.isCompleted ? accentColor : Color.gray.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if task.isCompleted {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.text)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    if task.isCompleted, let completedByName = task.completedByName {
                        Text("Completed by \(completedByName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -80)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3)) {
                            if value.translation.width < -50 {
                                offset = -80
                                showingDeleteButton = true
                            } else {
                                offset = 0
                                showingDeleteButton = false
                            }
                        }
                    }
            )
        }
        .frame(height: 56)
        .clipped()
    }
}

#Preview {
    VStack(spacing: 0) {
        TaskRow(
            task: TodoTask(text: "Buy groceries"),
            accentColor: .kaiPurple,
            onToggle: {},
            onDelete: {}
        )

        Divider()

        TaskRow(
            task: TodoTask(
                text: "Complete project",
                isCompleted: true,
                completedByName: "John"
            ),
            accentColor: .kaiTeal,
            onToggle: {},
            onDelete: {}
        )
    }
}
