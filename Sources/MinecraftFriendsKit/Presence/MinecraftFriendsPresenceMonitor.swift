import Foundation

@MainActor
public final class MinecraftFriendsPresenceMonitor {
    private let friendsService: MinecraftFriendsService
    private let host: any MinecraftFriendsPresenceMonitorHost
    private let localize: (String) -> String
    private let preferencesDidChangeNotification: Notification.Name?

    nonisolated(unsafe) private var preferencesObserver: NSObjectProtocol?
    private var preferencesInvalidationTask: Task<Void, Never>?

    private var trackedPlayerId: String?
    private var friendListPreferenceLoaded = false
    private var friendListEnabled = false

    private var presenceNotificationsReady = false
    private var lastStatusByFriendId: [String: MinecraftPresenceWireStatus]?
    private var seenInviteProfileIds = Set<String>()

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

    private func schedulePreferencesInvalidation() {
        preferencesInvalidationTask?.cancel()
        preferencesInvalidationTask = Task {
            invalidateFriendListPreferencesCache()
        }
    }

    private func invalidateFriendListPreferencesCache() {
        friendListPreferenceLoaded = false
    }

    private func resetForNewPlayer() {
        presenceNotificationsReady = false
        lastStatusByFriendId = nil
        seenInviteProfileIds = []
        friendListPreferenceLoaded = false
        Task { await friendsService.resetPresencePollingSchedule() }
    }

    public func tick(context: MinecraftFriendsPresenceTickContext) async {
        guard !isTicking else { return }
        isTicking = true
        defer { isTicking = false }

        let newId = context.playerId
        if newId != trackedPlayerId {
            trackedPlayerId = newId
            resetForNewPlayer()
        }

        guard let playerId = context.playerId, context.canUseMicrosoftMinecraftServices else { return }

        if !friendListPreferenceLoaded {
            guard let token = await host.friendsAccessToken(playerId: playerId) else { return }
            do {
                let p = try await friendsService.fetchFriendAccountPreferences(accessToken: token)
                friendListEnabled = (p.friends == .enabled)
                friendListPreferenceLoaded = true
            } catch {
                friendListEnabled = false
                friendListPreferenceLoaded = true
                return
            }
        }

        guard friendListEnabled else { return }

        let hasFriends = !(await friendsService.cachedFriendsLists()?.friends.isEmpty ?? true)
        guard await friendsService.shouldRefreshMinecraftPresenceForPolling(
            friendListEnabled: friendListEnabled,
            hasFriends: hasFriends
        ) else { return }

        guard let token = await host.friendsAccessToken(playerId: playerId) else { return }

        let presenceById: [String: MinecraftPresenceStatusDTO]
        do {
            presenceById = try await friendsService.fetchPresenceForPolling(accessToken: token)
        } catch {
            return
        }

        let cachedLists = await friendsService.cachedFriendsLists()
        let nameByProfileId = Self.nameLookup(from: cachedLists)
        let friendProfileIds = MinecraftFriendsPresenceState.friendProfileIds(from: cachedLists)
        let presenceForFriends = MinecraftFriendsPresenceState.filteredPresence(
            presenceById,
            friendProfileIds: friendProfileIds
        )

        if !presenceNotificationsReady {
            lastStatusByFriendId = MinecraftFriendsPresenceState.snapshotStatuses(
                from: presenceById,
                friendProfileIds: friendProfileIds
            )
            seenInviteProfileIds.formIntersection(friendProfileIds)
            presenceNotificationsReady = true
            return
        }

        guard let previous = lastStatusByFriendId else {
            lastStatusByFriendId = MinecraftFriendsPresenceState.snapshotStatuses(
                from: presenceById,
                friendProfileIds: friendProfileIds
            )
            return
        }

        let next = MinecraftFriendsPresenceState.snapshotStatuses(
            from: presenceById,
            friendProfileIds: friendProfileIds
        )
        defer { lastStatusByFriendId = next }

        await notifyPresenceChanges(
            presenceById: presenceForFriends,
            nameByProfileId: nameByProfileId,
            previous: previous,
            next: next
        )
        seenInviteProfileIds.formIntersection(friendProfileIds)
    }

    private func notifyPresenceChanges(
        presenceById: [String: MinecraftPresenceStatusDTO],
        nameByProfileId: [String: String],
        previous: [String: MinecraftPresenceWireStatus],
        next: [String: MinecraftPresenceWireStatus]
    ) async {
        for id in nameByProfileId.keys {
            guard let name = nameByProfileId[id] else { continue }

            let oldS = previous[id] ?? .offline
            let newS = next[id] ?? .offline
            let wasOn = Self.isPresenceOnline(oldS)
            let isOn = Self.isPresenceOnline(newS)

            if let row = presenceById[id], row.joinInfo?.invited == true {
                if seenInviteProfileIds.insert(id).inserted {
                    let body = localize("minecraft.friends.invite.invited_hint")
                    await host.sendSilentNotification(title: name, body: body)
                }
            } else {
                seenInviteProfileIds.remove(id)
            }

            if !wasOn, isOn {
                let body = localize("minecraft.friends.presence.online.notification")
                await host.sendSilentNotification(title: name, body: body)
            } else if wasOn, !isOn {
                let body = localize("minecraft.friends.presence.offline.notification")
                await host.sendSilentNotification(title: name, body: body)
            }
        }
    }

    private static func isPresenceOnline(_ s: MinecraftPresenceWireStatus) -> Bool {
        s != .offline
    }

    private static func nameLookup(from lists: MinecraftFriendsListResponse?) -> [String: String] {
        guard let lists else { return [:] }
        var names: [String: String] = [:]
        for friend in lists.friends {
            names[friend.profileId.normalized] = friend.name
        }
        return names
    }
}
