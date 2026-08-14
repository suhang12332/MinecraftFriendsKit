import Foundation

/// The severity level of a friends service error.
public enum MinecraftFriendsErrorLevel: Sendable {
    /// An error that requires immediate user attention via a popup dialog.
    case popup
    /// An error that can be reported through a system notification.
    case notification
    /// An error that should be handled silently without user notification.
    case silent
}

/// An error that can occur during Minecraft friends service operations.
public enum MinecraftFriendsServiceError: Error, Sendable {
    /// A network-level error, such as a connectivity failure or invalid HTTP response.
    case network(message: String, i18nKey: String, level: MinecraftFriendsErrorLevel)
    /// An authentication error, such as an expired or invalid access token.
    case authentication(message: String, i18nKey: String, level: MinecraftFriendsErrorLevel)
    /// A validation error, such as invalid request parameters or malformed data.
    case validation(message: String, i18nKey: String, level: MinecraftFriendsErrorLevel)
}
