import Foundation

actor MinecraftFriendsCoordinator {
    private static let friendsCooldown: TimeInterval = 10
    private static let presenceUpdateInterval: TimeInterval = 10
    private static let maxPresenceUpdateInterval: TimeInterval = 60

    private var friendsETag: String?
    private var presenceETag: String?
    private var lastLists: MinecraftFriendsListResponse?
    private var lastPresenceById: [String: MinecraftPresenceStatusDTO] = [:]
    private var lastFriendsFetchAt: Date?
    private var inflight: Task<MinecraftFriendsUIData, Error>?

    private var updatePresence = true
    private var lastPresencePostAt = Date()

    func markTryUpdatePresence() {
        updatePresence = true
    }

    func shouldRefreshPresence(friendListEnabled: Bool) -> Bool {
        guard friendListEnabled else { return false }
        let elapsed = Date().timeIntervalSince(lastPresencePostAt)
        let intervalEligible =
            updatePresence && elapsed >= Self.presenceUpdateInterval
            || elapsed >= Self.maxPresenceUpdateInterval
        guard intervalEligible else { return false }
        if let lists = lastLists, lists.friends.isEmpty, lists.incomingRequests.isEmpty { return false }
        return true
    }

    private func markPresencePingStarted() {
        updatePresence = false
        lastPresencePostAt = Date()
    }

    func applyPutFriendsSuccess(lists: MinecraftFriendsListResponse) {
        lastLists = lists
        friendsETag = nil
        updatePresence = true
    }

    func fetchBundle(accessToken: String, forceRefresh: Bool, service: MinecraftFriendsService) async throws -> MinecraftFriendsUIData {
        if let inflight {
            return try await inflight.value
        }
        let task = Task {
            try await self.fetchBundleInner(accessToken: accessToken, forceRefresh: forceRefresh, service: service)
        }
        inflight = task
        defer { inflight = nil }
        return try await task.value
    }

    private func fetchBundleInner(accessToken: String, forceRefresh: Bool, service: MinecraftFriendsService) async throws -> MinecraftFriendsUIData {
        let now = Date()
        let lists: MinecraftFriendsListResponse

        if !forceRefresh,
           let at = lastFriendsFetchAt,
           now.timeIntervalSince(at) < Self.friendsCooldown,
           let cached = lastLists {
            lists = cached
        } else {
            let getResult = try await service.executeGetFriends(accessToken: accessToken, ifNoneMatch: friendsETag)
            if getResult.status == 304 {
                lists = lastLists ?? .empty
            } else {
                lists = getResult.lists
                lastLists = lists
                if let e = getResult.etag, !e.isEmpty {
                    friendsETag = e
                }
            }
            lastFriendsFetchAt = Date()
        }

        let presenceBody = try service.jsonEncoder.encode(MinecraftPresenceRequest(status: .online, joinInfo: nil))
        markPresencePingStarted()
        let pres = try await service.executePostPresence(accessToken: accessToken, ifNoneMatch: presenceETag, body: presenceBody)

        if pres.status == 200 {
            var map: [String: MinecraftPresenceStatusDTO] = [:]
            for row in pres.presence.presence {
                map[row.profileId.normalized] = row
            }
            lastPresenceById = map
            if let e = pres.etag, !e.isEmpty {
                presenceETag = e
            }
        }

        return MinecraftFriendsUIData(lists: lists, presenceByProfileId: lastPresenceById)
    }
}
