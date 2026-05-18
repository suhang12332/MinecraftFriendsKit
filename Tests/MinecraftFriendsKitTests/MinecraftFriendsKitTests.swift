import XCTest
@testable import MinecraftFriendsKit

final class MinecraftFriendsKitTests: XCTestCase {
    func testPresenceSnapshotOnlyTracksFriends() {
        let friendId = "11111111111111111111111111111111"
        let strangerId = "22222222222222222222222222222222"
        let lists = MinecraftFriendsListResponse(
            friends: [MinecraftFriendProfileDTO(profileId: FlexibleUUIDString(normalized: friendId), name: "Friend")],
            incomingRequests: [],
            outgoingRequests: []
        )
        let friendIds = MinecraftFriendsPresenceState.friendProfileIds(from: lists)
        let presenceById: [String: MinecraftPresenceStatusDTO] = [
            friendId: MinecraftPresenceStatusDTO(
                profileId: FlexibleUUIDString(normalized: friendId),
                pmid: nil,
                status: .online,
                joinInfo: nil,
                lastUpdated: nil
            ),
            strangerId: MinecraftPresenceStatusDTO(
                profileId: FlexibleUUIDString(normalized: strangerId),
                pmid: nil,
                status: .online,
                joinInfo: nil,
                lastUpdated: nil
            ),
        ]

        let snapshot = MinecraftFriendsPresenceState.snapshotStatuses(
            from: presenceById,
            friendProfileIds: friendIds
        )
        XCTAssertEqual(Set(snapshot.keys), [friendId])
        XCTAssertEqual(snapshot[friendId], .online)

        let filtered = MinecraftFriendsPresenceState.filteredPresence(
            presenceById,
            friendProfileIds: friendIds
        )
        XCTAssertEqual(Set(filtered.keys), [friendId])
    }

    func testProductionAPIConfigurationHosts() {
        let c = MinecraftFriendsAPIConfiguration.production
        XCTAssertEqual(c.friendsListURL.host, "api.minecraftservices.com")
        XCTAssertEqual(c.presenceURL.host, "api.minecraftservices.com")
        XCTAssertEqual(c.playerAttributesURL.host, "api.minecraftservices.com")
        XCTAssertEqual(c.mojangSessionProfileBaseURL.host, "sessionserver.mojang.com")
    }
}
