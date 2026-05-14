import Foundation

public enum MinecraftFriendsErrorLevel: Sendable {
    case popup
    case notification
    case silent
}

public enum MinecraftFriendsServiceError: Error, Sendable {
    case network(message: String, i18nKey: String, level: MinecraftFriendsErrorLevel)
    case authentication(message: String, i18nKey: String, level: MinecraftFriendsErrorLevel)
    case validation(message: String, i18nKey: String, level: MinecraftFriendsErrorLevel)
}
