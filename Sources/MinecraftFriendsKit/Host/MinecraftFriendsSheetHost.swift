import Foundation

@MainActor
public protocol MinecraftFriendsSheetHost: AnyObject {
    func friendsAccessToken(playerId: String) async -> String?

    func reportFriendsError(_ error: Error)

    func skinTextureURL(uuidNoHyphens: String) async -> String?
}
