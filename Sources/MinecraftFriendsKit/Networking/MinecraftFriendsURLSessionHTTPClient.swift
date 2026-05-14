import Foundation

public final class MinecraftFriendsURLSessionHTTPClient: MinecraftFriendsHTTPClient, @unchecked Sendable {
    public static let shared = MinecraftFriendsURLSessionHTTPClient()

    private let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    public convenience init() {
        self.init(session: Self.makeDefaultSession())
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }

    public func performRequestWithResponse(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MinecraftFriendsServiceError.network(
                message: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }
        return (data, httpResponse)
    }
}
