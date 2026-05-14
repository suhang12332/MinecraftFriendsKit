import Foundation

public enum MinecraftFriendsSheetLocalize {
    public static func resolver(
        localeIdentifier: @escaping () -> String,
        fallback: @escaping (String) -> String
    ) -> (String) -> String {
        { key in
            if key.hasPrefix("minecraft.friends.") {
                return MinecraftFriendsKitLocalization.string(forKey: key, localeIdentifier: localeIdentifier())
            }
            return fallback(key)
        }
    }
}
