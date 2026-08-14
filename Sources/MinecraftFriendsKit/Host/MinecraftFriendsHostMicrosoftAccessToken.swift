import Foundation

/// Resolves a Microsoft access token for a Minecraft player through the token refresh flow.
///
/// This utility encapsulates the full token-refresh sequence: it verifies the bound
/// player ID, copies the player model, merges credentials from disk if needed,
/// attempts a token refresh, persists changes if the token changed, and applies
/// the refreshed player.
@MainActor
public enum MinecraftFriendsHostMicrosoftAccessToken {
    /// Resolves the Minecraft access token for the specified player.
    ///
    /// - Parameters:
    ///   - requestedPlayerId: The player ID to resolve the token for.
    ///   - boundPlayerId: A closure that returns the currently bound player ID.
    ///   - copyBoundPlayer: A closure that copies the current player model.
    ///   - mergeCredentialFromDiskIfNeeded: A closure that merges stored credentials into the player.
    ///   - minecraftAccessToken: A closure that extracts the access token from a player.
    ///   - refreshPlayerToken: A closure that refreshes the token for a player.
    ///   - persistIfMinecraftAccessTokenChanged: A closure that persists the player if the token changed.
    ///   - applyRefreshedPlayer: A closure that applies the refreshed player to the host.
    ///   - onMissingMinecraftAccessToken: A closure called when the access token is missing.
    ///   - onRefreshFailure: A closure called when the token refresh fails.
    /// - Returns: The resolved access token, or `nil` if resolution failed.
    public static func resolve<Player>(
        requestedPlayerId: String,
        boundPlayerId: @MainActor @escaping () -> String,
        copyBoundPlayer: @MainActor @escaping () -> Player?,
        mergeCredentialFromDiskIfNeeded: @MainActor @escaping (inout Player) -> Void,
        minecraftAccessToken: @MainActor @escaping (Player) -> String,
        refreshPlayerToken: @MainActor @escaping (Player) async throws -> Player,
        persistIfMinecraftAccessTokenChanged: @MainActor @escaping (_ before: Player, _ after: Player) async -> Void,
        applyRefreshedPlayer: @MainActor @escaping (Player) async -> Void,
        onMissingMinecraftAccessToken: @MainActor @escaping () -> Void,
        onRefreshFailure: @MainActor @escaping (Error) -> Void
    ) async -> String? {
        guard boundPlayerId() == requestedPlayerId else { return nil }
        guard var resolved = copyBoundPlayer() else { return nil }
        mergeCredentialFromDiskIfNeeded(&resolved)
        guard !minecraftAccessToken(resolved).isEmpty else {
            onMissingMinecraftAccessToken()
            return nil
        }

        do {
            let refreshed = try await refreshPlayerToken(resolved)
            if minecraftAccessToken(refreshed) != minecraftAccessToken(resolved) {
                await persistIfMinecraftAccessTokenChanged(resolved, refreshed)
            }
            await applyRefreshedPlayer(refreshed)
            return minecraftAccessToken(refreshed)
        } catch {
            onRefreshFailure(error)
            return nil
        }
    }
}
