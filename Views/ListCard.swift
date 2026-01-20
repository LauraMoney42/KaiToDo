import SwiftUI

struct ListCard: View {
    let list: TodoList

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(list.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()

                if list.isShared {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.caption)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(list.completedTaskCount)/\(list.totalTaskCount)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))

                    Spacer()

                    if list.totalTaskCount > 0 {
                        Text("\(Int(list.completionProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                if list.totalTaskCount > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.3))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: geometry.size.width * list.completionProgress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding()
        .frame(minHeight: 120)
        .background(Color(hex: list.color))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(hex: list.color).opacity(0.3), radius: 8, y: 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        ListCard(list: TodoList(
            name: "Groceries",
            color: "7161EF",
            tasks: [
                TodoTask(text: "Milk", isCompleted: true),
                TodoTask(text: "Eggs", isCompleted: true),
                TodoTask(text: "Bread"),
            ]
        ))

        ListCard(list: TodoList(
            name: "Work Tasks",
            color: "FF6B6B",
            tasks: [],
            isShared: true
        ))
    }
    .padding()
}
