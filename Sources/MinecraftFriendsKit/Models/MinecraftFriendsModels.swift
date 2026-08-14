import Foundation

/// A Minecraft friend profile returned by the friends list API.
public struct MinecraftFriendProfileDTO: Codable, Equatable, Sendable {
    /// The normalized profile ID (UUID without hyphens, lowercase).
    public let profileId: FlexibleUUIDString
    /// The player's display name.
    public let name: String

    /// Creates a new friend profile.
    ///
    /// - Parameters:
    ///   - profileId: The normalized profile ID.
    ///   - name: The player's display name.
    public init(profileId: FlexibleUUIDString, name: String) {
        self.profileId = profileId
        self.name = name
    }
}

/// The response from the Minecraft friends list API.
public struct MinecraftFriendsListResponse: Codable, Equatable, Sendable {
    /// The list of confirmed friends.
    public var friends: [MinecraftFriendProfileDTO]
    /// The list of incoming friend requests.
    public var incomingRequests: [MinecraftFriendProfileDTO]
    /// The list of outgoing friend requests.
    public var outgoingRequests: [MinecraftFriendProfileDTO]

    /// An empty friends list response.
    public static let empty = Self(
        friends: [],
        incomingRequests: [],
        outgoingRequests: []
    )

    private enum CodingKeys: String, CodingKey {
        case friends
        case incomingRequests
        case outgoingRequests
    }

    /// Creates a new friends list response.
    ///
    /// - Parameters:
    ///   - friends: The list of confirmed friends.
    ///   - incomingRequests: The list of incoming friend requests.
    ///   - outgoingRequests: The list of outgoing friend requests.
    public init(friends: [MinecraftFriendProfileDTO], incomingRequests: [MinecraftFriendProfileDTO], outgoingRequests: [MinecraftFriendProfileDTO]) {
        self.friends = friends
        self.incomingRequests = incomingRequests
        self.outgoingRequests = outgoingRequests
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        friends = try c.decodeIfPresent([MinecraftFriendProfileDTO].self, forKey: .friends) ?? []
        incomingRequests = try c.decodeIfPresent([MinecraftFriendProfileDTO].self, forKey: .incomingRequests) ?? []
        outgoingRequests = try c.decodeIfPresent([MinecraftFriendProfileDTO].self, forKey: .outgoingRequests) ?? []
    }
}

/// A request payload for performing a friend action (add, remove, accept, decline, revoke).
public struct MinecraftFriendActionRequest: Encodable, Sendable {
    /// The player name, used when adding a new friend by name.
    public var name: String?
    /// The profile ID, used when accepting, declining, revoking, or removing a friend.
    public var profileId: String?
    /// The type of update to perform (e.g., `"ADD"` or `"REMOVE"`).
    public let updateType: String

    /// Creates a new friend action request.
    ///
    /// - Parameters:
    ///   - name: The player name, or `nil` if not applicable.
    ///   - profileId: The profile ID, or `nil` if not applicable.
    ///   - updateType: The type of update to perform.
    public init(name: String? = nil, profileId: String? = nil, updateType: MinecraftFriendUpdateType) {
        self.name = name
        self.profileId = profileId
        self.updateType = updateType.rawValue
    }
}

/// The type of friend list update to perform.
public enum MinecraftFriendUpdateType: String, Sendable {
    /// Add or accept a friend.
    case add = "ADD"
    /// Remove, decline, or revoke a friend.
    case remove = "REMOVE"
}

/// A request payload for updating player attributes.
public struct MinecraftUserAttributesRequest: Encodable, Sendable {
    /// The friends preferences to update.
    public let friendsPreferences: MinecraftFriendsPreferencesPayload

    /// Creates a new user attributes request.
    ///
    /// - Parameter friendsPreferences: The friends preferences to update.
    public init(friendsPreferences: MinecraftFriendsPreferencesPayload) {
        self.friendsPreferences = friendsPreferences
    }
}

/// The payload for friends-related preferences.
public struct MinecraftFriendsPreferencesPayload: Codable, Equatable, Sendable {
    /// The friend list toggle state.
    public let friends: MinecraftToggleWireValue
    /// The accept invites toggle state.
    public let acceptInvites: MinecraftToggleWireValue

    /// Creates a new preferences payload.
    ///
    /// - Parameters:
    ///   - friends: The friend list toggle state.
    ///   - acceptInvites: The accept invites toggle state.
    public init(friends: MinecraftToggleWireValue, acceptInvites: MinecraftToggleWireValue) {
        self.friends = friends
        self.acceptInvites = acceptInvites
    }
}

/// A wire-format toggle value used for friend list preferences.
public enum MinecraftToggleWireValue: String, Codable, Sendable {
    /// The feature is enabled.
    case enabled = "ENABLED"
    /// The feature is disabled.
    case disabled = "DISABLED"

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = (try c.decode(String.self)).uppercased()
        self = Self(rawValue: raw) ?? .disabled
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// A request payload for posting the player's own presence.
public struct MinecraftPresenceRequest: Encodable, Sendable {
    /// The presence status string (e.g., `"ONLINE"`).
    public let status: String
    /// Optional join information to include with the presence update.
    public var joinInfo: MinecraftJoinInfoUpdate?

    /// Creates a new presence request.
    ///
    /// - Parameters:
    ///   - status: The presence status.
    ///   - joinInfo: Optional join information.
    public init(status: MinecraftPresenceWireStatus, joinInfo: MinecraftJoinInfoUpdate? = nil) {
        self.status = status.rawValue
        self.joinInfo = joinInfo
    }
}

/// Join information included with a presence update.
public struct MinecraftJoinInfoUpdate: Encodable, Sendable {
    /// The join info value (e.g., a server address).
    public let value: String
    /// Optional list of player UUIDs that have been invited.
    public var invites: [String]?

    /// Creates a new join info update.
    ///
    /// - Parameters:
    ///   - value: The join info value.
    ///   - invites: Optional list of invited player UUIDs.
    public init(value: String, invites: [String]? = nil) {
        self.value = value
        self.invites = invites
    }
}

/// The response from the presence API.
public struct MinecraftPresenceResponse: Codable, Equatable, Sendable {
    /// The list of presence status entries.
    public var presence: [MinecraftPresenceStatusDTO]

    /// Creates a new presence response.
    ///
    /// - Parameter presence: The list of presence status entries.
    public init(presence: [MinecraftPresenceStatusDTO]) {
        self.presence = presence
    }

    private enum CodingKeys: String, CodingKey {
        case presence
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        presence = try c.decodeIfPresent([MinecraftPresenceStatusDTO].self, forKey: .presence) ?? []
    }
}

/// A presence status entry for a single player.
public struct MinecraftPresenceStatusDTO: Codable, Equatable, Sendable {
    /// The normalized profile ID.
    public let profileId: FlexibleUUIDString
    /// The platform-mediated ID, if available.
    public let pmid: String?
    /// The current presence wire status.
    public let status: MinecraftPresenceWireStatus
    /// Optional join information.
    public var joinInfo: MinecraftPresenceJoinInfoDTO?
    /// The timestamp of the last update, if available.
    public var lastUpdated: String?
}

/// Join information from the presence API.
public struct MinecraftPresenceJoinInfoDTO: Codable, Equatable, Sendable {
    /// The join info value, or `nil` if not available.
    public let value: String?
    /// Whether the player has been invited to join.
    public let invited: Bool

    private enum CodingKeys: String, CodingKey {
        case value
        case invited
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = try c.decodeIfPresent(String.self, forKey: .value)
        invited = try c.decodeIfPresent(Bool.self, forKey: .invited) ?? false
    }
}

/// The wire-format presence status values returned by the Minecraft API.
public enum MinecraftPresenceWireStatus: String, Codable, Sendable, CaseIterable {
    /// The player is online.
    case online = "ONLINE"
    /// The player is in an offline world.
    case playingOffline = "PLAYING_OFFLINE"
    /// The player is on a Realm.
    case playingRealms = "PLAYING_REALMS"
    /// The player is on a dedicated server.
    case playingServer = "PLAYING_SERVER"
    /// The player is on a hosted server.
    case playingHostedServer = "PLAYING_HOSTED_SERVER"
    /// The player is offline.
    case offline = "OFFLINE"

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        self = Self(rawValue: s) ?? .offline
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// Combined UI data containing both friend lists and presence information.
public struct MinecraftFriendsUIData: Equatable, Sendable {
    /// The friend lists (friends, incoming requests, outgoing requests).
    public var lists: MinecraftFriendsListResponse
    /// The presence status for each friend, keyed by normalized profile ID.
    public var presenceByProfileId: [String: MinecraftPresenceStatusDTO]

    /// An empty UI data instance.
    public static let empty = Self(lists: MinecraftFriendsListResponse.empty, presenceByProfileId: [:])

    /// Creates a new UI data instance.
    ///
    /// - Parameters:
    ///   - lists: The friend lists.
    ///   - presenceByProfileId: The presence status map.
    public init(lists: MinecraftFriendsListResponse, presenceByProfileId: [String: MinecraftPresenceStatusDTO]) {
        self.lists = lists
        self.presenceByProfileId = presenceByProfileId
    }
}

/// A value type that normalizes UUID strings to a consistent format.
///
/// Accepts UUIDs with or without hyphens and stores them as lowercase
/// hex strings without hyphens. Provides a `dashedLowercase` property
/// for wire-format output.
public struct FlexibleUUIDString: Codable, Equatable, Hashable, Sendable {
    /// The normalized UUID string (32 hex characters, lowercase, no hyphens).
    public let normalized: String

    /// The UUID formatted with hyphens in lowercase (e.g., `"550e8400-e29b-41d4-a716-446655440000"`).
    ///
    /// Returns the original `normalized` string if it is not exactly 32 characters.
    public var dashedLowercase: String {
        guard normalized.count == 32 else { return normalized }
        let s = normalized
        let i = s.index(s.startIndex, offsetBy: 8)
        let j = s.index(i, offsetBy: 4)
        let k = s.index(j, offsetBy: 4)
        let l = s.index(k, offsetBy: 4)
        return "\(s[..<i])-\(s[i..<j])-\(s[j..<k])-\(s[k..<l])-\(s[l...])"
    }

    /// Creates a new flexible UUID string from a raw value.
    ///
    /// - Parameter normalized: The UUID string to normalize.
    public init(normalized: String) {
        self.normalized = Self.canonicalNoHyphens(normalized)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Empty profileId")
        }
        self.normalized = Self.canonicalNoHyphens(raw)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(normalized)
    }

    private static func canonicalNoHyphens(_ s: String) -> String {
        if let u = UUID(uuidString: s) {
            return u.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
        let cleaned = s.replacingOccurrences(of: "-", with: "").lowercased()
        if cleaned.count == 32, cleaned.allSatisfy({ $0.isHexDigit }) {
            return cleaned
        }
        return cleaned
    }
}
