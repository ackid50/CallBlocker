import Foundation

enum RuleExpander {
    static let maxPerRule = 1_000_000
    static let wildcards: Set<Character> = ["x", "X", "?", "*"]

    static func expand(_ rules: [Rule]) -> [Int64] {
        var set = Set<Int64>()
        for rule in rules where rule.enabled {
            set.formUnion(expandPattern(rule.pattern))
        }
        return set.sorted()
    }

    static func expandPattern(_ raw: String) -> [Int64] {
        let cleaned = raw.filter { $0.isNumber || wildcards.contains($0) }
        guard !cleaned.isEmpty else { return [] }
        let wildCount = cleaned.filter { wildcards.contains($0) }.count
        let total = pow10(wildCount)
        guard total > 0, total <= maxPerRule else { return [] }

        let template = Array(cleaned)
        var results: [Int64] = []
        results.reserveCapacity(total)
        var digits = Array(repeating: 0, count: wildCount)

        for _ in 0..<total {
            var buf = ""
            buf.reserveCapacity(template.count)
            var di = 0
            for ch in template {
                if wildcards.contains(ch) {
                    buf.append(Character(String(digits[di])))
                    di += 1
                } else {
                    buf.append(ch)
                }
            }
            if let n = Int64(buf) { results.append(n) }

            var i = wildCount - 1
            while i >= 0 {
                digits[i] += 1
                if digits[i] < 10 { break }
                digits[i] = 0
                i -= 1
            }
        }
        return results
    }

    private static func pow10(_ n: Int) -> Int {
        guard n >= 0 else { return 0 }
        if n == 0 { return 1 }
        var r = 1
        for _ in 0..<n { r *= 10 }
        return r
    }
}
