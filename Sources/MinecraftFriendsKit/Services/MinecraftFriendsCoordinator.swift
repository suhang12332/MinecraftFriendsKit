import Foundation

/// An actor that manages caching, throttling, and deduplication for background polling.
///
/// Tracks ETags for conditional requests (`If-None-Match` / `304 Not Modified`),
/// enforces 10-second and 60-second polling intervals, deduplicates in-flight
/// tasks for friend list and presence fetches, and caches the last-known state.
actor MinecraftFriendsCoordinator {
    private static let friendsUICooldown: TimeInterval = 10
    private static let presenceUpdateInterval: TimeInterval = 10
    private static let maxPresenceUpdateInterval: TimeInterval = 60

    private var friendsETag: String?
    private var presenceETag: String?
    private var lastLists: MinecraftFriendsListResponse?
    private var lastPresenceById: [String: MinecraftPresenceStatusDTO] = [:]
    private var lastFriendsFetchAt: Date?
    private var lastFriendListPollAt: Date?
    private var inflightBundle: Task<MinecraftFriendsUIData, Error>?
    private var inflightFriendsPoll: Task<MinecraftFriendsListResponse, Error>?
    private var inflightPresencePoll: Task<[String: MinecraftPresenceStatusDTO], Error>?

    private var updatePresence = true
    private var lastPresencePostAt = Date()
    private var updateFriendList = true

    /// Returns the cached friends list response, if available.
    func cachedLists() -> MinecraftFriendsListResponse? {
        lastLists
    }

    /// Resets the presence polling schedule so the next tick triggers a refresh.
    func resetPresencePollingSchedule() {
        lastPresencePostAt = Date()
        updatePresence = true
    }

    /// Resets the friend list polling schedule so the next tick triggers a refresh.
    func resetFriendListPollingSchedule() {
        lastFriendListPollAt = Date()
        updateFriendList = true
    }

    /// Marks the presence update flag so the next tick triggers a refresh.
    func markTryUpdatePresence() {
        updatePresence = true
    }

    /// Determines whether the friend list should be refreshed for polling.
    ///
    /// - Parameter friendListEnabled: Whether the friend list feature is enabled.
    /// - Returns: `true` if a refresh is needed based on elapsed time and flags.
    func shouldRefreshFriendListForPolling(friendListEnabled: Bool) -> Bool {
        guard friendListEnabled else { return false }
        guard let lastFriendListPollAt else { return true }
        let elapsed = Date().timeIntervalSince(lastFriendListPollAt)
        return updateFriendList && elapsed >= Self.presenceUpdateInterval
            || elapsed >= Self.maxPresenceUpdateInterval
    }

    /// Determines whether presence should be refreshed for polling.
    ///
    /// - Parameters:
    ///   - friendListEnabled: Whether the friend list feature is enabled.
    ///   - hasFriends: Whether the player has any friends.
    /// - Returns: `true` if a refresh is needed based on elapsed time and flags.
    func shouldRefreshPresence(friendListEnabled: Bool, hasFriends: Bool) -> Bool {
        guard friendListEnabled, hasFriends else { return false }
        let elapsed = Date().timeIntervalSince(lastPresencePostAt)
        let intervalEligible =
            updatePresence && elapsed >= Self.presenceUpdateInterval
            || elapsed >= Self.maxPresenceUpdateInterval
        return intervalEligible
    }

    private func markPresencePingStarted() {
        updatePresence = false
        lastPresencePostAt = Date()
    }

    private func markFriendListPollStarted() {
        updateFriendList = false
        lastFriendListPollAt = Date()
    }

    /// Fetches friend lists for polling, deduplicating concurrent requests.
    ///
    /// - Parameters:
    ///   - accessToken: The Microsoft access token.
    ///   - service: The friends service to execute the request.
    /// - Returns: The friends list response.
    func fetchFriendsListsForPolling(accessToken: String, service: MinecraftFriendsService) async throws -> MinecraftFriendsListResponse {
        if let inflightFriendsPoll {
            return try await inflightFriendsPoll.value
        }
        let task = Task {
            try await self.fetchFriendsListsForPollingInner(accessToken: accessToken, service: service)
        }
        inflightFriendsPoll = task
        defer { inflightFriendsPoll = nil }
        return try await task.value
    }

    private func fetchFriendsListsForPollingInner(
        accessToken: String,
        service: MinecraftFriendsService
    ) async throws -> MinecraftFriendsListResponse {
        markFriendListPollStarted()
        let getResult = try await service.executeGetFriends(accessToken: accessToken, ifNoneMatch: friendsETag)
        let lists: MinecraftFriendsListResponse
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
        return lists
    }

    /// Updates the cached friends list after a successful PUT friend action.
    ///
    /// - Parameter lists: The updated friends list response from the server.
    func applyPutFriendsSuccess(lists: MinecraftFriendsListResponse) {
        lastLists = lists
        friendsETag = nil
        updatePresence = true
        updateFriendList = true
    }

    /// Fetches presence data for polling, deduplicating concurrent requests.
    ///
    /// - Parameters:
    ///   - accessToken: The Microsoft access token.
    ///   - service: The friends service to execute the request.
    /// - Returns: A dictionary mapping profile IDs to their presence status.
    func fetchPresenceForPolling(accessToken: String, service: MinecraftFriendsService) async throws -> [String: MinecraftPresenceStatusDTO] {
        if let inflightPresencePoll {
            return try await inflightPresencePoll.value
        }
        let task = Task {
            try await self.fetchPresenceForPollingInner(accessToken: accessToken, service: service)
        }
        inflightPresencePoll = task
        defer { inflightPresencePoll = nil }
        return try await task.value
    }

    private func fetchPresenceForPollingInner(
        accessToken: String,
        service: MinecraftFriendsService
    ) async throws -> [String: MinecraftPresenceStatusDTO] {
        let presenceBody = try service.jsonEncoder.encode(MinecraftPresenceRequest(status: .online, joinInfo: nil))
        markPresencePingStarted()
        let pres = try await service.executePostPresence(accessToken: accessToken, ifNoneMatch: presenceETag, body: presenceBody)

        if pres.status == 200 {
            var map: [String: MinecraftPresenceStatusDTO] = [:]
            for row in pres.presence.presence {
                map[row.profileId.normalized] = row
            }
            let friendIds = MinecraftFriendsPresenceState.friendProfileIds(from: lastLists)
            map = MinecraftFriendsPresenceState.filteredPresence(map, friendProfileIds: friendIds)
            lastPresenceById = map
            if let e = pres.etag, !e.isEmpty {
                presenceETag = e
            }
            return map
        }
        let friendIds = MinecraftFriendsPresenceState.friendProfileIds(from: lastLists)
        return MinecraftFriendsPresenceState.filteredPresence(lastPresenceById, friendProfileIds: friendIds)
    }

    /// Fetches a combined bundle of friends list and presence data, deduplicating concurrent requests.
    ///
    /// - Parameters:
    ///   - accessToken: The Microsoft access token.
    ///   - forceRefresh: Whether to bypass the cache and fetch fresh data.
    ///   - service: The friends service to execute the request.
    /// - Returns: The combined UI data containing friend lists and presence information.
    func fetchBundle(accessToken: String, forceRefresh: Bool, service: MinecraftFriendsService) async throws -> MinecraftFriendsUIData {
        if let inflightBundle {
            return try await inflightBundle.value
        }
        let task = Task {
            try await self.fetchBundleInner(accessToken: accessToken, forceRefresh: forceRefresh, service: service)
        }
        inflightBundle = task
        defer { inflightBundle = nil }
        return try await task.value
    }

    private func fetchBundleInner(accessToken: String, forceRefresh: Bool, service: MinecraftFriendsService) async throws -> MinecraftFriendsUIData {
        let now = Date()
        let lists: MinecraftFriendsListResponse

        if !forceRefresh,
           let at = lastFriendsFetchAt,
           now.timeIntervalSince(at) < Self.friendsUICooldown,
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

        let presenceById = try await fetchPresenceForPollingInner(accessToken: accessToken, service: service)
        return MinecraftFriendsUIData(lists: lists, presenceByProfileId: presenceById)
    }
}
