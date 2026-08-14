import Combine
import Foundation

/// The view model driving the Minecraft friends sheet.
///
/// Manages friend lists, presence data, skin texture URLs, loading state,
/// and friend mutation operations (add, accept, decline, revoke, remove).
@MainActor
public final class MinecraftFriendsSheetViewModel: ObservableObject {
    /// The current UI data containing friend lists and presence information.
    @Published private(set) public var uiData: MinecraftFriendsUIData = .empty
    /// A map of normalized UUIDs to skin texture URL strings.
    @Published private(set) public var skinTextureURLByUUID: [String: String] = [:]
    /// Whether a data loading operation is in progress.
    @Published private(set) public var isLoading = false
    /// The text entered in the "Add Friend" text field.
    @Published public var addFriendName: String = ""

    private var contentEpoch: UInt64 = 0
    private var playerId: String = ""
    private weak var host: (any MinecraftFriendsSheetHost)?
    private let friendsService: MinecraftFriendsService

    /// Creates a new view model with the specified friends service.
    ///
    /// - Parameter friendsService: The service used for API operations.
    public init(friendsService: MinecraftFriendsService) {
        self.friendsService = friendsService
    }

    /// Prepares the view model for use with the specified player and host.
    ///
    /// - Parameters:
    ///   - playerId: The Minecraft player ID.
    ///   - host: The host providing authentication and error reporting.
    public func prepare(playerId: String, host: any MinecraftFriendsSheetHost) {
        self.playerId = playerId
        self.host = host
    }

    /// Clears all loaded data and resets the view model to its initial state.
    public func clearLoadedData() {
        contentEpoch &+= 1
        uiData = .empty
        skinTextureURLByUUID = [:]
        addFriendName = ""
        isLoading = false
    }

    /// Loads friend data, optionally forcing a refresh.
    ///
    /// - Parameter forceRefresh: Whether to bypass the cache and fetch fresh data.
    public func load(forceRefresh: Bool) async {
        let epoch = contentEpoch
        isLoading = true
        defer { isLoading = false }

        guard let host else { return }

        guard let token = await host.friendsAccessToken(playerId: playerId) else {
            guard epoch == contentEpoch else { return }
            uiData = .empty
            skinTextureURLByUUID = [:]
            return
        }

        do {
            try await reloadUIData(accessToken: token, forceRefresh: forceRefresh, epoch: epoch, host: host)
        } catch {
            host.reportFriendsError(error)
        }
    }

    /// Returns the skin texture URL for the specified normalized UUID, if available.
    ///
    /// - Parameter id: The normalized UUID (without hyphens, lowercase).
    /// - Returns: The skin texture URL string, or `nil` if not yet loaded.
    public func skinTextureURLString(forUUIDNormalized id: String) -> String? {
        skinTextureURLByUUID[id]
    }

    /// Sends a friend request using the current `addFriendName` value.
    public func sendFriendRequest() async {
        let name = addFriendName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: name, profileId: nil, updateType: .add)
        )
        addFriendName = ""
    }

    /// Accepts an incoming friend request from the specified player.
    ///
    /// - Parameter profileId: The dashed-lowercase profile ID of the player.
    public func acceptIncoming(profileId: String) async {
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .add)
        )
    }

    /// Declines an incoming friend request from the specified player.
    ///
    /// - Parameter profileId: The dashed-lowercase profile ID of the player.
    public func declineIncoming(profileId: String) async {
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .remove)
        )
    }

    /// Revokes an outgoing friend request sent to the specified player.
    ///
    /// - Parameter profileId: The dashed-lowercase profile ID of the player.
    public func revokeOutgoing(profileId: String) async {
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .remove)
        )
    }

    /// Removes the specified player from the friends list.
    ///
    /// - Parameter profileId: The dashed-lowercase profile ID of the player.
    public func removeFriend(profileId: String) async {
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .remove)
        )
    }

    private func runFriendMutation(request: MinecraftFriendActionRequest) async {
        await mutate { token in
            _ = try await friendsService.performFriendAction(accessToken: token, request: request)
        }
    }

    private func mutate(action: (String) async throws -> Void) async {
        guard let host else { return }
        let epoch = contentEpoch
        guard let token = await host.friendsAccessToken(playerId: playerId) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await action(token)
            guard epoch == contentEpoch else { return }
            try await reloadUIData(accessToken: token, forceRefresh: true, epoch: epoch, host: host)
        } catch {
            host.reportFriendsError(error)
        }
    }

    private func reloadUIData(
        accessToken: String,
        forceRefresh: Bool,
        epoch: UInt64,
        host: any MinecraftFriendsSheetHost
    ) async throws {
        let fetched = try await friendsService.fetchFriendsAndPresence(
            accessToken: accessToken,
            forceRefresh: forceRefresh
        )
        guard epoch == contentEpoch else { return }
        uiData = fetched
        await prefetchSkinTextureURLs(for: uiData, epoch: epoch, host: host)
    }

    private func prefetchSkinTextureURLs(for data: MinecraftFriendsUIData, epoch: UInt64, host: any MinecraftFriendsSheetHost) async {
        let ids = collectNormalizedUUIDs(from: data)
        if ids.isEmpty {
            if epoch == contentEpoch { skinTextureURLByUUID = [:] }
            return
        }

        let batchSize = 4
        var built: [String: String] = [:]
        for batchStart in stride(from: 0, to: ids.count, by: batchSize) {
            guard epoch == contentEpoch else { return }
            let end = min(batchStart + batchSize, ids.count)
            for id in ids[batchStart..<end] {
                guard epoch == contentEpoch else { return }
                if let url = await host.skinTextureURL(uuidNoHyphens: id), !url.isEmpty {
                    built[id] = url
                }
            }
        }
        guard epoch == contentEpoch else { return }
        skinTextureURLByUUID = built
    }

    private func collectNormalizedUUIDs(from data: MinecraftFriendsUIData) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        func appendUnique(_ list: [MinecraftFriendProfileDTO]) {
            for dto in list {
                let id = dto.profileId.normalized
                if seen.insert(id).inserted {
                    ordered.append(id)
                }
            }
        }
        appendUnique(data.lists.friends)
        appendUnique(data.lists.incomingRequests)
        appendUnique(data.lists.outgoingRequests)
        return ordered
    }
}
