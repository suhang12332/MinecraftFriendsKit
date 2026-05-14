import Foundation

public struct MinecraftFriendProfileDTO: Codable, Equatable, Sendable {
    public let profileId: FlexibleUUIDString
    public let name: String

    public init(profileId: FlexibleUUIDString, name: String) {
        self.profileId = profileId
        self.name = name
    }
}

public struct MinecraftFriendsListResponse: Codable, Equatable, Sendable {
    public var friends: [MinecraftFriendProfileDTO]
    public var incomingRequests: [MinecraftFriendProfileDTO]
    public var outgoingRequests: [MinecraftFriendProfileDTO]

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

public struct MinecraftFriendActionRequest: Encodable, Sendable {
    public var name: String?
    public var profileId: String?
    public let updateType: String

    public init(name: String? = nil, profileId: String? = nil, updateType: MinecraftFriendUpdateType) {
        self.name = name
        self.profileId = profileId
        self.updateType = updateType.rawValue
    }
}

public enum MinecraftFriendUpdateType: String, Sendable {
    case add = "ADD"
    case remove = "REMOVE"
}

public struct MinecraftUserAttributesRequest: Encodable, Sendable {
    public let friendsPreferences: MinecraftFriendsPreferencesPayload

    public init(friendsPreferences: MinecraftFriendsPreferencesPayload) {
        self.friendsPreferences = friendsPreferences
    }
}

public struct MinecraftFriendsPreferencesPayload: Codable, Equatable, Sendable {
    public let friends: MinecraftToggleWireValue
    public let acceptInvites: MinecraftToggleWireValue

    public init(friends: MinecraftToggleWireValue, acceptInvites: MinecraftToggleWireValue) {
        self.friends = friends
        self.acceptInvites = acceptInvites
    }
}

public enum MinecraftToggleWireValue: String, Codable, Sendable {
    case enabled = "ENABLED"
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

public struct MinecraftPresenceRequest: Encodable, Sendable {
    public let status: String
    public var joinInfo: MinecraftJoinInfoUpdate?

    public init(status: MinecraftPresenceWireStatus, joinInfo: MinecraftJoinInfoUpdate? = nil) {
        self.status = status.rawValue
        self.joinInfo = joinInfo
    }
}

public struct MinecraftJoinInfoUpdate: Encodable, Sendable {
    public let value: String
    public var invites: [String]?

    public init(value: String, invites: [String]? = nil) {
        self.value = value
        self.invites = invites
    }
}

public struct MinecraftPresenceResponse: Codable, Equatable, Sendable {
    public var presence: [MinecraftPresenceStatusDTO]

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

public struct MinecraftPresenceStatusDTO: Codable, Equatable, Sendable {
    public let profileId: FlexibleUUIDString
    public let pmid: String?
    public let status: MinecraftPresenceWireStatus
    public var joinInfo: MinecraftPresenceJoinInfoDTO?
    public var lastUpdated: String?
}

public struct MinecraftPresenceJoinInfoDTO: Codable, Equatable, Sendable {
    public let value: String?
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

public enum MinecraftPresenceWireStatus: String, Codable, Sendable, CaseIterable {
    case online = "ONLINE"
    case playingOffline = "PLAYING_OFFLINE"
    case playingRealms = "PLAYING_REALMS"
    case playingServer = "PLAYING_SERVER"
    case playingHostedServer = "PLAYING_HOSTED_SERVER"
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

public struct MinecraftFriendsUIData: Equatable, Sendable {
    public var lists: MinecraftFriendsListResponse
    public var presenceByProfileId: [String: MinecraftPresenceStatusDTO]

    public static let empty = Self(lists: MinecraftFriendsListResponse.empty, presenceByProfileId: [:])

    public init(lists: MinecraftFriendsListResponse, presenceByProfileId: [String: MinecraftPresenceStatusDTO]) {
        self.lists = lists
        self.presenceByProfileId = presenceByProfileId
    }
}

public struct FlexibleUUIDString: Codable, Equatable, Hashable, Sendable {
    public let normalized: String

    public var dashedLowercase: String {
        guard normalized.count == 32 else { return normalized }
        let s = normalized
        let i = s.index(s.startIndex, offsetBy: 8)
        let j = s.index(i, offsetBy: 4)
        let k = s.index(j, offsetBy: 4)
        let l = s.index(k, offsetBy: 4)
        return "\(s[..<i])-\(s[i..<j])-\(s[j..<k])-\(s[k..<l])-\(s[l...])"
    }

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
