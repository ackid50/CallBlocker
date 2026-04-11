import Foundation

enum RuleStore {
    static let appGroup = "group.com.callblocker.shared"
    static let fileName = "rules.json"

    static var fileURL: URL {
        let fm = FileManager.default
        if let base = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return base.appendingPathComponent(fileName)
        }
        return fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
}
