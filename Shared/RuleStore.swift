import Foundation

enum RuleStore {
    /// App group declared in the entitlements. Sideloading tools (Sideloadly,
    /// AltStore) re-sign the app with a personal team and usually rename the
    /// group, so the real identifier is resolved at runtime.
    static let baseAppGroup = "group.com.callblocker.shared"
    static let fileName = "rules.json"

    /// Shared container visible to both the app and the extension, or nil if
    /// the app was signed without a usable app group.
    static let sharedContainerURL: URL? = {
        let fm = FileManager.default
        for group in candidateGroups() {
            if let url = fm.containerURL(forSecurityApplicationGroupIdentifier: group) {
                return url
            }
        }
        return nil
    }()

    static var isShared: Bool { sharedContainerURL != nil }

    static var fileURL: URL {
        if let base = sharedContainerURL {
            return base.appendingPathComponent(fileName)
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    static func load() -> [Rule] {
        guard let data = try? Data(contentsOf: fileURL),
              let rules = try? JSONDecoder().decode([Rule].self, from: data)
        else { return [] }
        return rules
    }

    static func save(_ rules: [Rule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - App group resolution

    private static func candidateGroups() -> [String] {
        var groups: [String] = []
        // Groups actually granted by the provisioning profile this bundle was signed with.
        groups += provisionedGroups()
        // AltStore records the renamed groups here.
        if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
            groups += alt
        }
        groups.append(baseAppGroup)

        // Prefer the group derived from ours; keep the order stable so the app
        // and the extension pick the same one.
        let preferred = groups.filter { $0.contains("callblocker.shared") }.sorted()
        let others = groups.filter { !$0.contains("callblocker.shared") }.sorted()
        var seen = Set<String>()
        return (preferred + others).filter { seen.insert($0).inserted }
    }

    /// Reads the app groups out of embedded.mobileprovision (a signed blob
    /// wrapping an XML plist).
    private static func provisionedGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups
    }
}
