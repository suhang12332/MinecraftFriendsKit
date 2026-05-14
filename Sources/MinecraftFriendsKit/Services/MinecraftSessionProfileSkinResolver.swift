import Foundation
import OSLog

public enum MinecraftSessionProfileSkinResolver {
    private nonisolated(unsafe) static let hitCache = NSCache<NSString, NSString>()
    private static let log = Logger(subsystem: "MinecraftFriendsKit", category: "SessionSkin")

    private enum Mime {
        static let json = "application/json"
    }

    private enum Header {
        static let accept = "Accept"
    }

    public static func resolveTextureURLString(
        uuidNoHyphens: String,
        sessionProfileBaseURL: URL,
        httpClient: MinecraftFriendsHTTPClient
    ) async -> String? {
        let trimmed = uuidNoHyphens.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count == 32, trimmed.allSatisfy(\.isHexDigit) else { return nil }

        let cacheKey = trimmed as NSString
        if let cached = hitCache.object(forKey: cacheKey) {
            let s = cached as String
            return s.isEmpty ? nil : s
        }

        let url = sessionProfileBaseURL.appendingPathComponent(trimmed)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Mime.json, forHTTPHeaderField: Header.accept)

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
