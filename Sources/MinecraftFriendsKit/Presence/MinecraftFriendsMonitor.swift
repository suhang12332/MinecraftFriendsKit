import Foundation

/// Shared state and tick-preamble behavior for the presence and friend list monitors.
///
/// Handles the notification observer, friend list preference loading, and
/// per-player reset logic that both monitors otherwise duplicate.
@MainActor
open class MinecraftFriendsMonitor {
    let friendsService: MinecraftFriendsService
    let host: any MinecraftFriendsPresenceMonitorHost
    let localize: (String) -> String
    private let preferencesDidChangeNotification: Notification.Name?

    nonisolated(unsafe) private var preferencesObserver: NSObjectProtocol?
    private var preferencesInvalidationTask: Task<Void, Never>?

    private var trackedPlayerId: String?
    private var friendListPreferenceLoaded = false
    private(set) var friendListEnabled = false

    private var isTicking = false

    public init(
        friendsService: MinecraftFriendsService,
        host: any MinecraftFriendsPresenceMonitorHost,
        preferencesDidChangeNotification: Notification.Name?,
        localize: @escaping (String) -> String
    ) {
        self.friendsService = friendsService
        self.host = host
        self.preferencesDidChangeNotification = preferencesDidChangeNotification
        self.localize = localize

        if let preferencesDidChangeNotification {
            preferencesObserver = NotificationCenter.default.addObserver(
                forName: preferencesDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.schedulePreferencesInvalidation()
                }
            }
        }
    }

    deinit {
        preferencesInvalidationTask?.cancel()
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
    }

    /// Runs the common tick preamble and returns the active player ID if the
    /// tick should continue, or `nil` if it should be skipped.
    ///
    /// Resets per-player state when the player changes, skips when Microsoft
    /// Minecraft services are unavailable, and loads friend list preferences.
    /// - Parameters:
    ///   - playerId: The current player ID from the tick context.
    ///   - canUseMicrosoftMinecraftServices: Whether Microsoft services are available.
    ///   - resetPollingSchedule: The polling schedule reset for this monitor.
    /// - Returns: The active player ID when the tick should proceed, else `nil`.
    func beginTick(
        playerId: String?,
        canUseMicrosoftMinecraftServices: Bool,
        resetPollingSchedule: @escaping () async -> Void
    ) async -> String? {
        guard !isTicking else { return nil }
        isTicking = true
        defer { isTicking = false }

        if playerId != trackedPlayerId {
            trackedPlayerId = playerId
            resetForNewPlayer(resetPollingSchedule: resetPollingSchedule)
        }

        guard let playerId, canUseMicrosoftMinecraftServices else { return nil }

        if !friendListPreferenceLoaded {
            guard let token = await host.friendsAccessToken(playerId: playerId) else { return nil }
            do {
                let p = try await friendsService.fetchFriendAccountPreferences(accessToken: token)
                friendListEnabled = (p.friends == .enabled)
                friendListPreferenceLoaded = true
            } catch {
                friendListEnabled = false
                friendListPreferenceLoaded = true
                return nil
            }
        }

        guard friendListEnabled else { return nil }
        return playerId
    }

    /// Resets per-player state when the active player changes.
    func resetForNewPlayer(resetPollingSchedule: @escaping () async -> Void) {
        resetNotificationState()
        friendListPreferenceLoaded = false
        Task { await resetPollingSchedule() }
    }

    /// Resets notification tracking state for a new player. Subclasses override
    /// to clear their monitor-specific state.
    func resetNotificationState() {}

    private func schedulePreferencesInvalidation() {
        preferencesInvalidationTask?.cancel()
        preferencesInvalidationTask = Task {
            invalidateFriendListPreferencesCache()
        }
    }

    private func invalidateFriendListPreferencesCache() {
        friendListPreferenceLoaded = false
    }
}
