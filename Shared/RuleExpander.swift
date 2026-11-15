import Foundation

/// Turns wildcard patterns into concrete phone numbers.
///
/// iOS has no prefix/wildcard blocking: a Call Directory extension must hand
/// the system every single number, in ascending order. Numbers are therefore
/// generated lazily, so the extension never holds the whole list in memory
/// (extensions are killed if they use more than a few MB).
enum RuleExpander {
    static let maxPerRule = 1_000_000
    /// iOS rejects a directory beyond roughly this many entries per extension.
    static let recommendedTotal = 2_000_000
    static let maxDigits = 15 // E.164
    static let wildcards: Set<Character> = ["x", "X", "?", "*"]

    /// Yields the numbers of one pattern in ascending order.
    struct Generator {
        let base: Int64
        let places: [Int64] // place value of each wildcard, most significant first
        let total: Int
        private var index = 0

        init(base: Int64, places: [Int64], total: Int) {
            self.base = base
            self.places = places
            self.total = total
        }

        mutating func next() -> Int64? {
            guard index < total else { return nil }
            var n = base
            var rem = index
            for place in places.reversed() {
                n += Int64(rem % 10) * place
                rem /= 10
            }
            index += 1
            return n
        }
    }

    static func generator(for raw: String) -> Generator? {
        let cleaned = Array(raw.filter { ($0.isASCII && $0.isNumber) || wildcards.contains($0) })
        guard !cleaned.isEmpty, cleaned.count <= maxDigits else { return nil }

        var base: Int64 = 0
        var places: [Int64] = []
        var place: Int64 = 1
        for ch in cleaned.reversed() {
            if wildcards.contains(ch) {
                places.insert(place, at: 0)
            } else if let d = ch.wholeNumberValue {
                base += Int64(d) * place
            }
            place *= 10
        }

        var total = 1
        for _ in places {
            total *= 10
            if total > maxPerRule { return nil }
        }
        return Generator(base: base, places: places, total: total)
    }

    /// How many numbers a pattern covers (0 if invalid or too large).
    static func count(_ raw: String) -> Int {
        generator(for: raw)?.total ?? 0
    }

    /// Upper bound on entries for the enabled rules (overlaps counted twice).
    static func totalCount(_ rules: [Rule]) -> Int {
        rules.filter { $0.enabled }.reduce(0) { $0 + count($1.pattern) }
    }

    /// Calls `body` with every number covered by the enabled rules, ascending
    /// and without duplicates, using constant memory.
    static func forEachNumber(in rules: [Rule], _ body: (Int64) -> Void) {
        var gens = rules.filter { $0.enabled }.compactMap { generator(for: $0.pattern) }
        var heads: [Int64?] = []
        for i in gens.indices { heads.append(gens[i].next()) }

        while true {
            var smallest: Int64?
            for h in heads {
                if let h = h, smallest == nil || h < smallest! { smallest = h }
            }
            guard let n = smallest else { return }
            if n > 0 { body(n) }
            for i in gens.indices where heads[i] == n {
                heads[i] = gens[i].next()
            }
        }
    }
}
