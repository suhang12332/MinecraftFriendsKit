import Foundation

/// Monitors friend presence status changes on a periodic tick cycle.
///
/// On each tick, this monitor checks the player ID, loads friend list preferences,
/// polls the presence API if the polling interval has elapsed, compares previous
/// versus new statuses of each friend, and sends silent notifications when a friend
/// comes online, goes offline, or has a pending invite.
@MainActor
public final class MinecraftFriendsPresenceMonitor: MinecraftFriendsMonitor {
    private var presenceNotificationsReady = false
    private var lastStatusByFriendId: [String: MinecraftPresenceWireStatus]?
    private var seenInviteProfileIds = Set<String>()

    /// Creates a new presence monitor.
    ///
    /// - Parameters:
    ///   - friendsService: The service used for API operations.
    ///   - host: The host providing authentication and notification delivery.
    ///   - preferencesDidChangeNotification: An optional notification name to observe for preference changes.
    ///   - localize: A closure that resolves localization keys to strings.
    public override init(
        friendsService: MinecraftFriendsService,
        host: any MinecraftFriendsPresenceMonitorHost,
        preferencesDidChangeNotification: Notification.Name?,
        localize: @escaping (String) -> String
    ) {
        super.init(
            friendsService: friendsService,
            host: host,
            preferencesDidChangeNotification: preferencesDidChangeNotification,
            localize: localize
        )
    }

    override func resetNotificationState() {
        presenceNotificationsReady = false
        lastStatusByFriendId = nil
        seenInviteProfileIds = []
    }

    /// Executes a single tick of the presence monitoring loop.
    ///
    /// - Parameter context: The tick context containing the current player ID
    ///   and service availability flag.
    public func tick(context: MinecraftFriendsPresenceTickContext) async {
        guard let playerId = await beginTick(
            playerId: context.playerId,
            canUseMicrosoftMinecraftServices: context.canUseMicrosoftMinecraftServices,
            resetPollingSchedule: { await self.friendsService.resetPresencePollingSchedule() }
        ) else { return }

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
        let next = MinecraftFriendsPresenceState.snapshotStatuses(
            from: presenceById,
            friendProfileIds: friendProfileIds
        )

        guard presenceNotificationsReady, let previous = lastStatusByFriendId else {
            lastStatusByFriendId = next
            seenInviteProfileIds.formIntersection(friendProfileIds)
            presenceNotificationsReady = true
            return
        }

        lastStatusByFriendId = next
        await notifyPresenceChanges(
            presenceById: presenceById,
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
