import Foundation

/// Polls the Minecraft friends list on a periodic cadence and emits silent
/// notifications for incoming and accepted friend requests.
///
/// Monitors friend list changes by comparing snapshots between tick cycles,
/// sending notifications when new incoming requests or accepted outgoing
/// requests are detected.
@MainActor
public final class MinecraftFriendsFriendListMonitor: MinecraftFriendsMonitor {
    private var notificationsReady = false
    private var knownIncomingRequestProfileIds = Set<String>()
    private var lastOutgoingRequestProfileIds: Set<String>?

    /// Creates a new friend list monitor.
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
        notificationsReady = false
        knownIncomingRequestProfileIds = []
        lastOutgoingRequestProfileIds = nil
    }

    /// Executes a single tick of the friend list polling loop.
    ///
    /// - Parameter context: The tick context containing the current player ID
    ///   and service availability flag.
    public func tick(context: MinecraftFriendsFriendListTickContext) async {
        guard let playerId = await beginTick(
            playerId: context.playerId,
            canUseMicrosoftMinecraftServices: context.canUseMicrosoftMinecraftServices,
            resetPollingSchedule: { await self.friendsService.resetFriendListPollingSchedule() }
        ) else { return }

        guard await friendsService.shouldRefreshFriendListForPolling(friendListEnabled: friendListEnabled) else {
            return
        }

        guard let token = await host.friendsAccessToken(playerId: playerId) else { return }

        let lists: MinecraftFriendsListResponse
        do {
            lists = try await friendsService.fetchFriendsListsForPolling(accessToken: token)
        } catch {
            return
        }

        if !notificationsReady {
            knownIncomingRequestProfileIds = Self.snapshotIncomingRequestIds(from: lists)
            lastOutgoingRequestProfileIds = Self.snapshotOutgoingRequestIds(from: lists)
            notificationsReady = true
            return
        }

        let previousOutgoing = lastOutgoingRequestProfileIds ?? []
        await notifyNewIncomingFriendRequests(from: lists)
        await notifyAcceptedOutgoingFriendRequests(from: lists, previousOutgoing: previousOutgoing)
        lastOutgoingRequestProfileIds = Self.snapshotOutgoingRequestIds(from: lists)
    }

    private func notifyNewIncomingFriendRequests(from lists: MinecraftFriendsListResponse) async {
        let currentIds = Self.snapshotIncomingRequestIds(from: lists)
        defer { knownIncomingRequestProfileIds.formIntersection(currentIds) }

        for req in lists.incomingRequests {
            let id = req.profileId.normalized
            guard knownIncomingRequestProfileIds.insert(id).inserted else { continue }
            let body = localize("minecraft.friends.request.incoming_hint")
            await host.sendSilentNotification(title: req.name, body: body)
        }
    }

    private func notifyAcceptedOutgoingFriendRequests(
        from lists: MinecraftFriendsListResponse,
        previousOutgoing: Set<String>
    ) async {
        let currentOutgoing = Self.snapshotOutgoingRequestIds(from: lists)
        let currentFriendIds = Set(lists.friends.map { $0.profileId.normalized })
        let acceptedIds = previousOutgoing.subtracting(currentOutgoing).intersection(currentFriendIds)

        for friend in lists.friends {
            let id = friend.profileId.normalized
            guard acceptedIds.contains(id) else { continue }
            let body = localize("minecraft.friends.request.accepted_hint")
            await host.sendSilentNotification(title: friend.name, body: body)
        }
    }

    private static func snapshotIncomingRequestIds(from lists: MinecraftFriendsListResponse) -> Set<String> {
        Set(lists.incomingRequests.map { $0.profileId.normalized })
    }

    private static func snapshotOutgoingRequestIds(from lists: MinecraftFriendsListResponse) -> Set<String> {
        Set(lists.outgoingRequests.map { $0.profileId.normalized })
    }
}
