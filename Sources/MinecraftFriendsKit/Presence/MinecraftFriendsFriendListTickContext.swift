import Foundation

public struct MinecraftFriendsFriendListTickContext: Sendable, Equatable {
    public let playerId: String?
    public let canUseMicrosoftMinecraftServices: Bool

    public init(playerId: String?, canUseMicrosoftMinecraftServices: Bool) {
        self.playerId = playerId
        self.canUseMicrosoftMinecraftServices = canUseMicrosoftMinecraftServices
    }
}
