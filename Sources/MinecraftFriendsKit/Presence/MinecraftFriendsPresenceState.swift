import Foundation

/// Utility functions for managing presence notification state.
///
/// Presence notification state is scoped to the current friends list so polling
/// does not retain every profile ID returned by the presence API.
enum MinecraftFriendsPresenceState {
    /// Returns the set of profile IDs from the friends list.
    ///
    /// - Parameter lists: The friends list response, or `nil`.
    /// - Returns: A set of normalized profile IDs.
    static func friendProfileIds(from lists: MinecraftFriendsListResponse?) -> Set<String> {
        guard let lists else { return [] }
        return Set(lists.friends.map { $0.profileId.normalized })
    }

    /// Takes a snapshot of current presence statuses for the given friend profile IDs.
    ///
    /// - Parameters:
    ///   - presenceById: The full presence map keyed by profile ID.
    ///   - friendProfileIds: The set of friend profile IDs to snapshot.
    /// - Returns: A dictionary mapping profile IDs to their presence wire status.
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

    /// Filters the presence map to include only entries for the specified friend profile IDs.
    ///
    /// - Parameters:
    ///   - presenceById: The full presence map keyed by profile ID.
    ///   - friendProfileIds: The set of friend profile IDs to include.
    /// - Returns: A filtered presence map containing only friend entries.
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
