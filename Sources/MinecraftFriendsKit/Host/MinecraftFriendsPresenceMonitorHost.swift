import Foundation

/// A host-provided interface for presence and friend list monitoring services.
///
/// The host application must conform to this protocol to provide authentication
/// tokens and notification delivery for the presence and friend list monitors.
@MainActor
public protocol MinecraftFriendsPresenceMonitorHost: AnyObject {
    /// Returns the Microsoft access token for the specified player.
    ///
    /// - Parameter playerId: The Minecraft player ID.
    /// - Returns: The access token, or `nil` if unavailable.
    func friendsAccessToken(playerId: String) async -> String?

    /// Sends a silent system notification with the given title and body.
    ///
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    func sendSilentNotification(title: String, body: String) async
}
