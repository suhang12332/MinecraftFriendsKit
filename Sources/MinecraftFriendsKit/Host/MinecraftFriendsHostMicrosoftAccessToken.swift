import Foundation

@MainActor
public enum MinecraftFriendsHostMicrosoftAccessToken {
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
