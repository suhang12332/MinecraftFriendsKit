import Foundation

public final class MinecraftFriendsService: @unchecked Sendable {
    private let configuration: MinecraftFriendsAPIConfiguration
    private let httpClient: MinecraftFriendsHTTPClient
    private let jsonDecoder: JSONDecoder
    let jsonEncoder: JSONEncoder
    private let coordinator = MinecraftFriendsCoordinator()

    public init(
        configuration: MinecraftFriendsAPIConfiguration = .production,
        httpClient: MinecraftFriendsHTTPClient = MinecraftFriendsURLSessionHTTPClient.shared
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.jsonDecoder = decoder
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        self.jsonEncoder = encoder
    }

    public func fetchFriendsAndPresence(accessToken: String, forceRefresh: Bool) async throws -> MinecraftFriendsUIData {
        try await coordinator.fetchBundle(
            accessToken: accessToken,
            forceRefresh: forceRefresh,
            service: self
        )
    }

    public func resolveSessionProfileSkinTextureURL(uuidNoHyphens: String) async -> String? {
        await MinecraftSessionProfileSkinResolver.resolveTextureURLString(
            uuidNoHyphens: uuidNoHyphens,
            sessionProfileBaseURL: configuration.mojangSessionProfileBaseURL,
            httpClient: httpClient
        )
    }

    public func performFriendAction(accessToken: String, request: MinecraftFriendActionRequest) async throws -> MinecraftFriendsListResponse {
        let urlRequest = Self.authenticatedJSONRequest(
            url: configuration.friendsListURL,
            method: "PUT",
            accessToken: accessToken,
            body: try jsonEncoder.encode(request)
        )
        let (data, http) = try await httpClient.performRequestWithResponse(request: urlRequest)
        try Self.throwIfFailedResponse(http: http, data: data)

        let lists = try jsonDecoder.decode(MinecraftFriendsListResponse.self, from: data)
        await coordinator.applyPutFriendsSuccess(lists: lists)
        return lists
    }

    public func updateFriendSettings(
        accessToken: String,
        enableFriendlist: Bool,
        enableFriendInvites: Bool
    ) async throws {
        let body = MinecraftUserAttributesRequest(
            friendsPreferences: MinecraftFriendsPreferencesPayload(
                friends: enableFriendlist ? .enabled : .disabled,
                acceptInvites: enableFriendInvites ? .enabled : .disabled
            )
        )
        let urlRequest = Self.authenticatedJSONRequest(
            url: configuration.playerAttributesURL,
            method: "POST",
            accessToken: accessToken,
            body: try jsonEncoder.encode(body)
        )
        let (data, http) = try await httpClient.performRequestWithResponse(request: urlRequest)
        try Self.throwIfFailedResponse(http: http, data: data)
        markPresenceRefreshSoon()
    }

    public func markPresenceRefreshSoon() {
        Task { await coordinator.markTryUpdatePresence() }
    }

    public func shouldRefreshMinecraftPresenceForPolling(friendListEnabled: Bool) async -> Bool {
        await coordinator.shouldRefreshPresence(friendListEnabled: friendListEnabled)
    }

    public func fetchFriendAccountPreferences(accessToken: String) async throws -> MinecraftFriendsPreferencesPayload {
        let urlRequest = Self.authenticatedJSONRequest(
            url: configuration.playerAttributesURL,
            method: "GET",
            accessToken: accessToken,
            body: nil
        )
        let (data, http) = try await httpClient.performRequestWithResponse(request: urlRequest)
        try Self.throwIfFailedResponse(http: http, data: data)
        guard let parsed = Self.extractFriendsPreferencesPayload(from: data) else {
            throw MinecraftFriendsServiceError.validation(
                message: "无法解析账号好友偏好设置",
                i18nKey: "minecraft.friends.settings.parse_failed",
                level: .notification
            )
        }
        return parsed
    }

    func executeGetFriends(accessToken: String, ifNoneMatch: String?) async throws -> (
        lists: MinecraftFriendsListResponse,
        status: Int,
        etag: String?
    ) {
        let urlRequest = Self.authenticatedJSONRequest(
            url: configuration.friendsListURL,
            method: "GET",
            accessToken: accessToken,
            ifNoneMatch: ifNoneMatch
        )
        let (data, http) = try await httpClient.performRequestWithResponse(request: urlRequest)
        let code = http.statusCode
        if code == 304 {
            return (.empty, code, Self.etag(from: http))
        }
        if (200 ... 299).contains(code) {
            let lists = try jsonDecoder.decode(MinecraftFriendsListResponse.self, from: data)
            return (lists, code, Self.etag(from: http))
        }
        return try Self.throwingFriendsGETFailure(http: http, data: data, code: code)
    }

    func executePostPresence(accessToken: String, ifNoneMatch: String?, body: Data) async throws -> (
        presence: MinecraftPresenceResponse,
        status: Int,
        etag: String?
    ) {
        let urlRequest = Self.authenticatedJSONRequest(
            url: configuration.presenceURL,
            method: "POST",
            accessToken: accessToken,
            body: body,
            ifNoneMatch: ifNoneMatch
        )
        let (data, http) = try await httpClient.performRequestWithResponse(request: urlRequest)
        let code = http.statusCode
        if code == 304 {
            return (MinecraftPresenceResponse(presence: []), code, Self.etag(from: http))
        }
        if (200 ... 299).contains(code) {
            let pr = try jsonDecoder.decode(MinecraftPresenceResponse.self, from: data)
            return (pr, code, Self.etag(from: http))
        }
        return try Self.throwingPresencePOSTFailure(http: http, data: data, code: code)
    }

    private static func throwingFriendsGETFailure(http: HTTPURLResponse, data: Data, code: Int) throws -> (
        lists: MinecraftFriendsListResponse,
        status: Int,
        etag: String?
    ) {
        try throwIfFailedResponse(http: http, data: data)
        throw MinecraftFriendsServiceError.network(
            message: "好友接口返回未处理的 HTTP \(code)",
            i18nKey: "error.network.api_request_failed",
            level: .notification
        )
    }

    private static func throwingPresencePOSTFailure(http: HTTPURLResponse, data: Data, code: Int) throws -> (
        presence: MinecraftPresenceResponse,
        status: Int,
        etag: String?
    ) {
        try throwIfFailedResponse(http: http, data: data)
        throw MinecraftFriendsServiceError.network(
            message: "Presence 接口返回未处理的 HTTP \(code)",
            i18nKey: "error.network.api_request_failed",
            level: .notification
        )
    }

    private enum Mime {
        static let json = "application/json"
    }

    private enum Header {
        static let accept = "Accept"
        static let contentType = "Content-Type"
    }

    private static func authenticatedJSONRequest(
        url: URL,
        method: String,
        accessToken: String,
        body: Data? = nil,
        ifNoneMatch: String? = nil
    ) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        r.setValue(Mime.json, forHTTPHeaderField: Header.accept)
        if let body {
            r.setValue(Mime.json, forHTTPHeaderField: Header.contentType)
            r.httpBody = body
        }
        if let ifNoneMatch, !ifNoneMatch.isEmpty {
            r.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
        }
        return r
    }

    private static func etag(from response: HTTPURLResponse) -> String? {
        if let v = response.value(forHTTPHeaderField: "ETag") { return v }
        return response.value(forHTTPHeaderField: "Etag")
    }

    private static func throwIfFailedResponse(http: HTTPURLResponse, data: Data) throws {
        let code = http.statusCode
        if (200 ... 299).contains(code) { return }

        switch code {
        case 401:
            throw MinecraftFriendsServiceError.authentication(
                message: "Minecraft 访问令牌无效或已过期，请重新登录",
                i18nKey: "error.authentication.token_expired",
                level: .popup
            )
        case 403:
            throw MinecraftFriendsServiceError.authentication(
                message: "没有权限访问好友服务 (403)",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        case 400:
            let detail = parseFriendsErrorDetail(from: data)
            throw MinecraftFriendsServiceError.validation(
                message: detail?.chineseMessage ?? "无效的请求参数",
                i18nKey: detail?.i18nKey ?? "error.validation.invalid_request",
                level: .notification
            )
        case 429:
            throw MinecraftFriendsServiceError.network(
                message: "请求过于频繁，请稍后再试",
                i18nKey: "error.network.rate_limited",
                level: .notification
            )
        case 500 ... 599:
            throw MinecraftFriendsServiceError.network(
                message: "好友服务暂时不可用 (HTTP \(code))",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        default:
            let snippet = String(data: data.prefix(256), encoding: .utf8) ?? ""
            throw MinecraftFriendsServiceError.network(
                message: "好友接口错误 HTTP \(code): \(snippet)",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        }
    }

    private struct MinecraftPlayerAttributesGETEnvelope: Decodable {
        var friendsPreferences: MinecraftFriendsPreferencesPayload?
        var preferences: PreferencesNode?

        struct PreferencesNode: Decodable {
            var friendsPreferences: MinecraftFriendsPreferencesPayload?
        }
    }

    private static func extractFriendsPreferencesPayload(from data: Data) -> MinecraftFriendsPreferencesPayload? {
        if let env = try? JSONDecoder().decode(MinecraftPlayerAttributesGETEnvelope.self, from: data) {
            if let fp = env.friendsPreferences { return fp }
            if let fp = env.preferences?.friendsPreferences { return fp }
        }
        return extractFriendsPreferencesPayloadLegacy(from: data)
    }

    private static func extractFriendsPreferencesPayloadLegacy(from data: Data) -> MinecraftFriendsPreferencesPayload? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let p = parseFriendsPreferencesFromAttributesDict(root) { return p }
        if let pref = root["preferences"] as? [String: Any], let p = parseFriendsPreferencesFromAttributesDict(pref) { return p }
        if let pref = root["Preferences"] as? [String: Any], let p = parseFriendsPreferencesFromAttributesDict(pref) { return p }
        return nil
    }

    private static func parseFriendsPreferencesFromAttributesDict(_ dict: [String: Any]) -> MinecraftFriendsPreferencesPayload? {
        if let fp = dict["friendsPreferences"] as? [String: Any] ?? dict["friends_preferences"] as? [String: Any] {
            return decodeFriendsPreferencesObject(fp)
        }
        return nil
    }

    private static func decodeFriendsPreferencesObject(_ fp: [String: Any]) -> MinecraftFriendsPreferencesPayload? {
        let friendsRaw = (fp["friends"] as? String) ?? (fp["Friends"] as? String)
        let invitesRaw = (fp["acceptInvites"] as? String) ?? (fp["AcceptInvites"] as? String)
        guard let f = friendsRaw, let i = invitesRaw else { return nil }
        let friends = MinecraftToggleWireValue(rawValue: f.uppercased()) ?? .disabled
        let invites = MinecraftToggleWireValue(rawValue: i.uppercased()) ?? .disabled
        return MinecraftFriendsPreferencesPayload(friends: friends, acceptInvites: invites)
    }

    private static func parseFriendsErrorDetail(from data: Data) -> (chineseMessage: String, i18nKey: String)? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let details = obj["details"] as? [String: Any] ?? obj["Details"] as? [String: Any]
        let status = details?["status"] as? String ?? details?["Status"] as? String
        switch status {
        case "UNKNOWN_PROFILE":
            return ("找不到该玩家名称或档案", "minecraft.friends.error.unknown_profile")
        case "CANNOT_ADD_SELF":
            return ("不能添加自己为好友", "minecraft.friends.error.cannot_add_self")
        case "DUPLICATED_PROFILES":
            return ("重复的玩家档案", "minecraft.friends.error.duplicated_profiles")
        default:
            return nil
        }
    }
}
