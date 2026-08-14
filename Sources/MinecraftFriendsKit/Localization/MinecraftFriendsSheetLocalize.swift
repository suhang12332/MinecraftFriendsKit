import Foundation

/// A factory that produces localization resolver closures for the friends sheet.
///
/// Keys prefixed with `minecraft.friends.` are resolved via
/// ``MinecraftFriendsKitLocalization``; all other keys are forwarded to
/// a fallback closure provided by the host.
public enum MinecraftFriendsSheetLocalize {
    /// Creates a localization resolver function.
    ///
    /// - Parameters:
    ///   - localeIdentifier: A closure that returns the current locale identifier.
    ///   - fallback: A closure that resolves localization keys not handled by this kit.
    /// - Returns: A closure that maps localization keys to localized strings.
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
