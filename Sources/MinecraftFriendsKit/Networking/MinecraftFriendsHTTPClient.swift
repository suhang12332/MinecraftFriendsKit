import Foundation

/// A protocol that defines an interface for performing HTTP requests.
///
/// Conforming types provide the networking layer for all Minecraft friends
/// service API calls.
public protocol MinecraftFriendsHTTPClient: Sendable {
    /// Performs an HTTP request and returns the raw data and URL response.
    ///
    /// - Parameter request: The URL request to execute.
    /// - Returns: A tuple containing the response data and the HTTP URL response.
    /// - Throws: An error if the request fails.
    func performRequestWithResponse(request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
