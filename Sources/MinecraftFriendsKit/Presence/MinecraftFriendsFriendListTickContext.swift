import Foundation

/// The context passed to a friend list monitor tick.
///
/// Contains the current player ID and whether Microsoft Minecraft services
/// are available for the tick cycle.
public struct MinecraftFriendsFriendListTickContext: Sendable, Equatable {
    /// The Minecraft player ID, or `nil` if no player is active.
    public let playerId: String?
    /// Whether Microsoft Minecraft services are available for this tick.
    public let canUseMicrosoftMinecraftServices: Bool

    /// Creates a new tick context.
    ///
    /// - Parameters:
    ///   - playerId: The Minecraft player ID, or `nil` if no player is active.
    ///   - canUseMicrosoftMinecraftServices: Whether Microsoft Minecraft services are available.
    public init(playerId: String?, canUseMicrosoftMinecraftServices: Bool) {
        self.playerId = playerId
        self.canUseMicrosoftMinecraftServices = canUseMicrosoftMinecraftServices
    }
}
