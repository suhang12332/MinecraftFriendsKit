import Foundation

/// A ``MinecraftFriendsHTTPClient`` implementation backed by `URLSession`.
///
/// Uses a default session with 30-second request timeout, 60-second resource
/// timeout, and a maximum of 6 connections per host.
public final class MinecraftFriendsURLSessionHTTPClient: MinecraftFriendsHTTPClient, @unchecked Sendable {
    /// The shared singleton instance using the default session configuration.
    public static let shared = MinecraftFriendsURLSessionHTTPClient()

    private let session: URLSession

    /// Creates a client with the specified URL session.
    ///
    /// - Parameter session: The URL session to use for requests.
    public init(session: URLSession) {
        self.session = session
    }

    /// Creates a client with the default session configuration.
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
                message: "Invalid HTTP response",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }
        return (data, httpResponse)
    }
}
