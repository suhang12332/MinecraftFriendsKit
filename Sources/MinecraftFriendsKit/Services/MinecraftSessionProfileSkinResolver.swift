import Foundation
import OSLog

/// Resolves a Minecraft player's UUID to a skin texture URL via the Mojang session profile API.
///
/// Uses an in-memory `NSCache` to avoid repeated network fetches for the same player.
/// Parses the base64-encoded textures property from the session profile JSON response
/// and normalizes HTTP URLs to HTTPS.
public enum MinecraftSessionProfileSkinResolver {
    private nonisolated(unsafe) static let hitCache = NSCache<NSString, NSString>()
    private static let log = Logger(subsystem: "MinecraftFriendsKit", category: "SessionSkin")

    /// Resolves the skin texture URL for the specified player UUID.
    ///
    /// - Parameters:
    ///   - uuidNoHyphens: The player UUID without hyphens (32 hex characters).
    ///   - sessionProfileBaseURL: The base URL for the Mojang session profile API.
    ///   - httpClient: The HTTP client to use for the request.
    /// - Returns: The skin texture URL string, or `nil` if unavailable.
    public static func resolveTextureURLString(
        uuidNoHyphens: String,
        sessionProfileBaseURL: URL,
        httpClient: MinecraftFriendsHTTPClient
    ) async -> String? {
        let trimmed = uuidNoHyphens.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count == 32, trimmed.allSatisfy(\.isHexDigit) else { return nil }

        let cacheKey = trimmed as NSString
        if let cached = hitCache.object(forKey: cacheKey) as String? {
            return cached.isEmpty ? nil : cached
        }

        let url = sessionProfileBaseURL.appendingPathComponent(trimmed)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, http) = try await httpClient.performRequestWithResponse(request: request)
            guard (200 ... 299).contains(http.statusCode) else { return nil }
            guard let urlString = skinTextureURL(fromSessionProfileJSON: data), !urlString.isEmpty else {
                return nil
            }
            hitCache.setObject(urlString as NSString, forKey: cacheKey)
            return urlString
        } catch {
            let prefix = String(trimmed.prefix(8))
            log.debug("SessionSkin fetch failed uuid=\(prefix, privacy: .public) \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Extracts the skin texture URL from a Mojang session profile JSON response.
    ///
    /// - Parameter data: The raw JSON data from the session profile endpoint.
    /// - Returns: The skin texture URL string, or `nil` if parsing fails.
    public static func skinTextureURL(fromSessionProfileJSON data: Data) -> String? {
        struct Prop: Codable { let name: String; let value: String }
        struct SessionProfile: Codable { let properties: [Prop]? }
        struct TexturesPayload: Codable { let textures: TexturesInner? }
        struct TexturesInner: Codable { let SKIN: SkinEntry? }
        struct SkinEntry: Codable { let url: String }

        guard let profile = try? JSONDecoder().decode(SessionProfile.self, from: data),
              let prop = profile.properties?.first(where: { $0.name == "textures" }),
              let decoded = Data(base64Encoded: prop.value),
              let payload = try? JSONDecoder().decode(TexturesPayload.self, from: decoded),
              let urlStr = payload.textures?.SKIN?.url
        else {
            return nil
        }
        return urlStr.normalizingSkinTextureURLSchemeToHTTPS()
    }
}

private extension String {
    func normalizingSkinTextureURLSchemeToHTTPS() -> String {
        guard let url = URL(string: self) else { return self }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return self }
        if components.scheme?.lowercased() == "http" {
            components.scheme = "https"
            return components.url?.absoluteString ?? self
        }
        return self
    }
}
