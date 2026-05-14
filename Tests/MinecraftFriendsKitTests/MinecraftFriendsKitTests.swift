import XCTest
@testable import MinecraftFriendsKit

final class MinecraftFriendsKitTests: XCTestCase {
    func testProductionAPIConfigurationHosts() {
        let c = MinecraftFriendsAPIConfiguration.production
        XCTAssertEqual(c.friendsListURL.host, "api.minecraftservices.com")
        XCTAssertEqual(c.presenceURL.host, "api.minecraftservices.com")
        XCTAssertEqual(c.playerAttributesURL.host, "api.minecraftservices.com")
        XCTAssertEqual(c.mojangSessionProfileBaseURL.host, "sessionserver.mojang.com")
    }
}
