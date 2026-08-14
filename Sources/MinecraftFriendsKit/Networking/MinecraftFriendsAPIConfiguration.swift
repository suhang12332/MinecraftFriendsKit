import Foundation

/// The API endpoint configuration for the Minecraft friends service.
///
/// Contains the URLs for friends list, presence, player attributes,
/// and Mojang session profile endpoints.
public struct MinecraftFriendsAPIConfiguration: Sendable {
    /// The URL for the friends list API.
    public let friendsListURL: URL
    /// The URL for the presence API.
    public let presenceURL: URL
    /// The URL for the player attributes API.
    public let playerAttributesURL: URL
    /// The base URL for the Mojang session profile API.
    public let mojangSessionProfileBaseURL: URL

    /// Creates a new API configuration.
    ///
    /// - Parameters:
    ///   - friendsListURL: The URL for the friends list API.
    ///   - presenceURL: The URL for the presence API.
    ///   - playerAttributesURL: The URL for the player attributes API.
    ///   - mojangSessionProfileBaseURL: The base URL for the Mojang session profile API.
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

    /// The production API configuration pointing to the official Minecraft services endpoints.
    public static let production = MinecraftFriendsAPIConfiguration(
        friendsListURL: URL(string: "https://api.minecraftservices.com/friends")!,
        presenceURL: URL(string: "https://api.minecraftservices.com/presence")!,
        playerAttributesURL: URL(string: "https://api.minecraftservices.com/player/attributes")!
    )
}
