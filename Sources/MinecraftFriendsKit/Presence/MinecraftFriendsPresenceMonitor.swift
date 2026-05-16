import Foundation

@MainActor
public final class MinecraftFriendsPresenceMonitor {
    private let friendsService: MinecraftFriendsService
    private let host: any MinecraftFriendsPresenceMonitorHost
    private let localize: (String) -> String
    private let preferencesDidChangeNotification: Notification.Name?

    nonisolated(unsafe) private var preferencesObserver: NSObjectProtocol?

    private var trackedPlayerId: String?
    private var friendListPreferenceLoaded = false
    private var friendListEnabled = false

    private var lastStatusByFriendId: [String: MinecraftPresenceWireStatus]?
    private var seenInviteProfileIds = Set<String>()
    private var knownIncomingRequestProfileIds = Set<String>()
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
                Task { @MainActor in self?.invalidateFriendListPreferencesCache() }
            }
        }
    }

    deinit {
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
        }
    }

    private func invalidateFriendListPreferencesCache() {
        friendListPreferenceLoaded = false
    }

    private func resetForNewPlayer() {
        lastStatusByFriendId = nil
        seenInviteProfileIds = []
        knownIncomingRequestProfileIds = []
        friendListPreferenceLoaded = false
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

        guard let token = await host.friendsAccessToken(playerId: playerId) else { return }

        guard await friendsService.shouldRefreshMinecraftPresenceForPolling(friendListEnabled: friendListEnabled) else { return }

        let data: MinecraftFriendsUIData
        do {
            data = try await friendsService.fetchFriendsAndPresence(
                accessToken: token,
                forceRefresh: false
            )
        } catch {
            return
        }

        guard let previous = lastStatusByFriendId else {
            lastStatusByFriendId = Self.snapshotStatuses(from: data)
            knownIncomingRequestProfileIds = Self.snapshotIncomingRequestIds(from: data)
            return
        }

        let next = Self.snapshotStatuses(from: data)
        defer { lastStatusByFriendId = next }

        await notifyNewIncomingFriendRequests(from: data)

        for f in data.lists.friends {
            let id = f.profileId.normalized
            let name = f.name
            let oldS = previous[id] ?? .offline
            let newS = next[id] ?? .offline
            let wasOn = Self.isPresenceOnline(oldS)
            let isOn = Self.isPresenceOnline(newS)

            if let row = data.presenceByProfileId[id], row.joinInfo?.invited == true {
                if seenInviteProfileIds.insert(id).inserted {
                    let body = localize("minecraft.friends.invite.invited_hint")
                    await host.sendSilentNotification(title: name, body: body)
                }
            } else {
                seenInviteProfileIds.remove(id)
            }

            if !wasOn, isOn {
                let body = localize("minecraft.friends.presence.online")
                await host.sendSilentNotification(title: name, body: body)
            } else if wasOn, !isOn {
                let body = localize("minecraft.friends.presence.offline")
                await host.sendSilentNotification(title: name, body: body)
            }
        }
    }

    private func notifyNewIncomingFriendRequests(from data: MinecraftFriendsUIData) async {
        let currentIds = Self.snapshotIncomingRequestIds(from: data)
        defer { knownIncomingRequestProfileIds.formIntersection(currentIds) }

        for req in data.lists.incomingRequests {
            let id = req.profileId.normalized
            guard knownIncomingRequestProfileIds.insert(id).inserted else { continue }
            let body = localize("minecraft.friends.request.incoming_hint")
            await host.sendSilentNotification(title: req.name, body: body)
        }
    }

    private static func isPresenceOnline(_ s: MinecraftPresenceWireStatus) -> Bool {
        s != .offline
    }

    private static func snapshotIncomingRequestIds(from data: MinecraftFriendsUIData) -> Set<String> {
        Set(data.lists.incomingRequests.map { $0.profileId.normalized })
    }

    private static func snapshotStatuses(from data: MinecraftFriendsUIData) -> [String: MinecraftPresenceWireStatus] {
        var m: [String: MinecraftPresenceWireStatus] = [:]
        for f in data.lists.friends {
            let id = f.profileId.normalized
            m[id] = data.presenceByProfileId[id]?.status ?? .offline
        }
        return m
    }
}
