import Foundation

/// A host-provided interface for the friends sheet UI.
///
/// The host application must conform to this protocol to provide authentication,
/// error reporting, and skin texture resolution for the friends sheet.
@MainActor
public protocol MinecraftFriendsSheetHost: AnyObject {
    /// Returns the Microsoft access token for the specified player.
    ///
    /// - Parameter playerId: The Minecraft player ID.
    /// - Returns: The access token, or `nil` if unavailable.
    func friendsAccessToken(playerId: String) async -> String?

    /// Reports an error that occurred during a friends service operation.
    ///
    /// - Parameter error: The error to report.
    func reportFriendsError(_ error: Error)

    /// Resolves the skin texture URL for a player identified by their UUID without hyphens.
    ///
    /// - Parameter uuidNoHyphens: The player UUID formatted without hyphens.
    /// - Returns: The skin texture URL string, or `nil` if unavailable.
    func skinTextureURL(uuidNoHyphens: String) async -> String?
}
