import Combine
import Foundation

@MainActor
public final class MinecraftFriendsSheetViewModel: ObservableObject {
    @Published private(set) public var uiData: MinecraftFriendsUIData = .empty
    @Published private(set) public var skinTextureURLByUUID: [String: String] = [:]
    @Published private(set) public var isLoading = false
    @Published public var addFriendName: String = ""

    private var contentEpoch: UInt64 = 0
    private var playerId: String = ""
    private weak var host: (any MinecraftFriendsSheetHost)?
    private let friendsService: MinecraftFriendsService

    public init(friendsService: MinecraftFriendsService) {
        self.friendsService = friendsService
    }

    public func prepare(playerId: String, host: any MinecraftFriendsSheetHost) {
        self.playerId = playerId
        self.host = host
    }

    public func clearLoadedData() {
        contentEpoch &+= 1
        uiData = .empty
        skinTextureURLByUUID = [:]
        addFriendName = ""
        isLoading = false
    }

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
            let fetched = try await friendsService.fetchFriendsAndPresence(
                accessToken: token,
                forceRefresh: forceRefresh
            )
            guard epoch == contentEpoch else { return }
            uiData = fetched
            await prefetchSkinTextureURLs(for: uiData, epoch: epoch, host: host)
        } catch {
            host.reportFriendsError(error)
        }
    }

    public func skinTextureURLString(forUUIDNormalized id: String) -> String? {
        skinTextureURLByUUID[id]
    }

    public func sendFriendRequest() async {
        let name = addFriendName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: name, profileId: nil, updateType: .add)
        )
        addFriendName = ""
    }

    public func acceptIncoming(profileId: String) async {
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .add)
        )
    }

    public func declineIncoming(profileId: String) async {
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .remove)
        )
    }

    public func revokeOutgoing(profileId: String) async {
        await runFriendMutation(
            request: MinecraftFriendActionRequest(name: nil, profileId: profileId, updateType: .remove)
        )
    }

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
            let fetched = try await friendsService.fetchFriendsAndPresence(
                accessToken: token,
                forceRefresh: true
            )
            guard epoch == contentEpoch else { return }
            uiData = fetched
            await prefetchSkinTextureURLs(for: uiData, epoch: epoch, host: host)
        } catch {
            host.reportFriendsError(error)
        }
    }

    private func prefetchSkinTextureURLs(for data: MinecraftFriendsUIData, epoch: UInt64, host: any MinecraftFriendsSheetHost) async {
        let ids = collectNormalizedUUIDs(from: data)
        guard !ids.isEmpty else {
            guard epoch == contentEpoch else { return }
            skinTextureURLByUUID = [:]
            return
        }

        let batchSize = 4
        var built: [String: String] = [:]
        var start = 0
        while start < ids.count {
            guard epoch == contentEpoch else { return }
            let end = min(start + batchSize, ids.count)
            let batch = Array(ids[start..<end])
            for id in batch {
                guard epoch == contentEpoch else { return }
                if let url = await host.skinTextureURL(uuidNoHyphens: id), !url.isEmpty {
                    built[id] = url
                }
            }
            start = end
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
