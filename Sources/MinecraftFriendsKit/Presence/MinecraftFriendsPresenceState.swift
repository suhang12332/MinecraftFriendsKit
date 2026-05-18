import Foundation

/// Presence notification state is scoped to the current friends list so polling
/// does not retain every profile id returned by the presence API.
enum MinecraftFriendsPresenceState {
    static func friendProfileIds(from lists: MinecraftFriendsListResponse?) -> Set<String> {
        guard let lists else { return [] }
        return Set(lists.friends.map { $0.profileId.normalized })
    }

    static func snapshotStatuses(
        from presenceById: [String: MinecraftPresenceStatusDTO],
        friendProfileIds: Set<String>
    ) -> [String: MinecraftPresenceWireStatus] {
        var statuses: [String: MinecraftPresenceWireStatus] = [:]
        statuses.reserveCapacity(friendProfileIds.count)
        for id in friendProfileIds {
            statuses[id] = presenceById[id]?.status ?? .offline
        }
        return statuses
    }

    static func filteredPresence(
        _ presenceById: [String: MinecraftPresenceStatusDTO],
        friendProfileIds: Set<String>
    ) -> [String: MinecraftPresenceStatusDTO] {
        guard !friendProfileIds.isEmpty else { return [:] }
        var filtered: [String: MinecraftPresenceStatusDTO] = [:]
        filtered.reserveCapacity(friendProfileIds.count)
        for id in friendProfileIds {
            if let row = presenceById[id] {
                filtered[id] = row
            }
        }
        return filtered
    }
}
