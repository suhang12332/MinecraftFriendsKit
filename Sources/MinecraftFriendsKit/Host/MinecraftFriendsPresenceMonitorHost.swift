import Foundation

@MainActor
public protocol MinecraftFriendsPresenceMonitorHost: AnyObject {
    func friendsAccessToken(playerId: String) async -> String?

    func sendSilentNotification(title: String, body: String) async
}
