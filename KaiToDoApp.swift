import SwiftUI

@main
struct KaiToDoApp: App {
    @State private var listsViewModel = ListsViewModel()
    @State private var userViewModel = UserViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(listsViewModel)
                .environment(userViewModel)
        }
    }
}

// MARK: - Color Extensions

extension Color {
    static let kaiPurple = Color(hex: "7161EF")
    static let kaiRed = Color(hex: "FF6B6B")
    static let kaiTeal = Color(hex: "4ECDC4")
    static let kaiYellow = Color(hex: "FFE66D")
    static let kaiOrange = Color(hex: "FF8C42")
    static let kaiMint = Color(hex: "95E1D3")
    static let kaiPink = Color(hex: "F38181")
    static let kaiBlue = Color(hex: "3D5A80")

    static let listColors: [Color] = [
        kaiPurple, kaiRed, kaiTeal, kaiYellow,
        kaiOrange, kaiMint, kaiPink, kaiBlue
    ]

    static let listColorHexes: [String] = [
        "7161EF", "FF6B6B", "4ECDC4", "FFE66D",
        "FF8C42", "95E1D3", "F38181", "3D5A80"
    ]

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
