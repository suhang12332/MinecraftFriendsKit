import Foundation

public protocol MinecraftFriendsHTTPClient: Sendable {
    func performRequestWithResponse(request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
