import Foundation

public struct MinecraftFriendsAPIConfiguration: Sendable {
    public let friendsListURL: URL
    public let presenceURL: URL
    public let playerAttributesURL: URL
    public let mojangSessionProfileBaseURL: URL

    public init(
        friendsListURL: URL,
        presenceURL: URL,
        playerAttributesURL: URL,
        mojangSessionProfileBaseURL: URL = URL(string: "https://sessionserver.mojang.com/session/minecraft/profile/")!
    ) {
        self.friendsListURL = friendsListURL
        self.presenceURL = presenceURL
        self.playerAttributesURL = playerAttributesURL
        self.mojangSessionProfileBaseURL = mojangSessionProfileBaseURL
    }

    public static let production = MinecraftFriendsAPIConfiguration(
        friendsListURL: URL(string: "https://api.minecraftservices.com/friends")!,
        presenceURL: URL(string: "https://api.minecraftservices.com/presence")!,
        playerAttributesURL: URL(string: "https://api.minecraftservices.com/player/attributes")!,
        mojangSessionProfileBaseURL: URL(string: "https://sessionserver.mojang.com/session/minecraft/profile/")!
    )
}
