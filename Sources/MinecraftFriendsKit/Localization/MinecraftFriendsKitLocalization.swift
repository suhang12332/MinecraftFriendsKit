import Foundation

public enum MinecraftFriendsKitLocalization {
    private static let missingSentinel = "\u{FFFC}"

    public static func string(forKey key: String, localeIdentifier: String) -> String {
        let bundle = Bundle.module
        for code in localizationLookupCodes(for: localeIdentifier, bundle: bundle) {
            guard let path = bundle.path(forResource: code, ofType: "lproj"),
                  let locBundle = Bundle(path: path)
            else { continue }

            let resolved = locBundle.localizedString(forKey: key, value: missingSentinel, table: nil)
            if resolved != missingSentinel {
                return resolved
            }
        }

        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    private static func localizationLookupCodes(for localeIdentifier: String, bundle: Bundle) -> [String] {
        var codes: [String] = []
        let trimmed = localeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            codes.append(trimmed)
            if trimmed.contains("_") {
                codes.append(trimmed.replacingOccurrences(of: "_", with: "-"))
            }
        }
        if let p = bundle.preferredLocalizations.first, !p.isEmpty {
            codes.append(p)
        }
        codes.append(contentsOf: ["zh-Hans", "en"])

        var seen = Set<String>()
        return codes.filter { seen.insert($0).inserted }
    }
}
