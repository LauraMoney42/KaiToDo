import SwiftUI

struct TaskRow: View {
    let task: TodoTask
    let accentColor: Color
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
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
                            .transition(.scale.combined(with: .opacity))

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                // Spring scale + fade on the whole checkmark widget when state changes
                .scaleEffect(task.isCompleted ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: task.isCompleted)
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }
}

#Preview {
    List {
        TaskRow(
            task: TodoTask(text: "Buy groceries"),
            accentColor: .kaiPurple,
            onToggle: {},
            onDelete: {}
        )

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
