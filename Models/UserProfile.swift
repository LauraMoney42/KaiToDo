import Foundation

struct UserProfile: Codable, Equatable {
    let userID: String
    var nickname: String
    var deviceToken: String?
    let createdAt: Date

    init(
        userID: String = UUID().uuidString,
        nickname: String,
        deviceToken: String? = nil,
        createdAt: Date = Date()
    ) {
        self.userID = userID
        self.nickname = nickname
        self.deviceToken = deviceToken
        self.createdAt = createdAt
    }

    var isValid: Bool {
        nickname.count >= 2 && nickname.count <= 20
    }
}
