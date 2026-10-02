import Foundation

/// Fuzzy matcher tuned for launcher queries: short, typed fast, often abbreviations.
///
/// Scores a query against a candidate string. Higher is better; nil means no match.
/// Every query character must appear in order in the candidate (case- and diacritic-insensitive).
public enum Matcher {
    public struct Match: Equatable {
        public let score: Int
        /// Indices into the candidate that matched, for highlighting.
        public let positions: [Int]
    }

    // Scoring weights. Kept as named constants so tests can reason about ordering.
    static let exactBonus = 1000
    static let prefixBonus = 400
    static let wordStartBonus = 60
    static let consecutiveBonus = 60
    static let acronymBonus = 60
    static let fullAcronymBonus = 30
    static let baseCharScore = 10
    static let gapPenalty = 8
    static let lengthPenaltyPerChar = 1

    public static func match(query: String, in candidate: String) -> Match? {
        let q = normalise(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return Match(score: 0, positions: []) }
        let c = normalise(candidate).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return nil }

        if q == c { return Match(score: exactBonus, positions: Array(0..<c.count)) }

        let cChars = Array(c)
        let qChars = Array(q)
        let wordStarts = wordStartIndices(cChars)

        // Pass 1: acronym match — every query char hits a word start, in order.
        if let acro = acronymMatch(qChars, cChars, wordStarts: wordStarts) {
            return acro
        }

        // Pass 2: greedy subsequence preferring word starts, then consecutive runs.
        guard let positions = subsequence(qChars, cChars, wordStarts: wordStarts) else { return nil }

        var score = 0
        var previous = -2
        for (i, pos) in positions.enumerated() {
            score += baseCharScore
            if pos == previous + 1 { score += consecutiveBonus }
            if wordStarts.contains(pos) { score += wordStartBonus }
            if i == 0 && pos == 0 { score += prefixBonus }
            if i > 0 && pos > previous + 1 { score -= gapPenalty * (pos - previous - 1) }
            previous = pos
        }
        score -= lengthPenaltyPerChar * max(0, cChars.count - qChars.count)
        return Match(score: score, positions: positions)
    }

    /// Best match across the item's name and keywords.
    public static func match(query: String, hop: Hop) -> Match? {
        var best = match(query: query, in: hop.name)
        for keyword in hop.keywords {
            if let m = match(query: query, in: keyword) {
                // Keyword hits count a little less than a name hit so "Finder" beats a keyword alias,
                // but when the keyword also exists in the displayed name we keep the positions aligned to that name.
                let adjusted = Match(score: m.score - 20,
                    positions: positionsForKeywordMatch(query: query, in: hop.name, keyword: keyword) ?? [])
                if best == nil || adjusted.score > best!.score { best = adjusted }
            }
        }
        return best
    }

    // MARK: - Helpers

    private static func positionsForKeywordMatch(query: String, in name: String, keyword: String) -> [Int]? {
        let q = normalise(query).trimmingCharacters(in: .whitespacesAndNewlines)
        let n = normalise(name).trimmingCharacters(in: .whitespacesAndNewlines)
        let k = normalise(keyword).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !q.isEmpty, !n.isEmpty else { return nil }
        if q == n { return Array(0..<n.count) }

        guard let range = n.range(of: k) else { return nil }
        let start = n.distance(from: n.startIndex, to: range.lowerBound)
        let end = n.distance(from: n.startIndex, to: range.upperBound)
        return Array(start..<end)
    }

    static func normalise(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func wordStartIndices(_ chars: [Character]) -> Set<Int> {
        var starts = Set<Int>()
        for (i, ch) in chars.enumerated() {
            if i == 0 { if ch.isLetter || ch.isNumber { starts.insert(0) }; continue }
            let prev = chars[i - 1]
            let boundary = !(prev.isLetter || prev.isNumber)
            if (ch.isLetter || ch.isNumber) && boundary { starts.insert(i) }
        }
        return starts
    }

    private static func acronymMatch(_ q: [Character], _ c: [Character], wordStarts: Set<Int>) -> Match? {
        let starts = wordStarts.sorted()
        guard q.count >= 2, q.count <= starts.count else { return nil }
        var positions: [Int] = []
        var si = 0
        for qc in q {
            var found = false
            while si < starts.count {
                let idx = starts[si]; si += 1
                if c[idx] == qc { positions.append(idx); found = true; break }
            }
            if !found { return nil }
        }
        // Each hit is a word start; an acronym from the first word gets most (not all) of the
        // prefix bonus, so a typed prefix like "sl" → Slack still edges out "sl" → System Library.
        var score = acronymBonus + q.count * (baseCharScore + wordStartBonus)
        if positions.first == 0 { score += prefixBonus * 3 / 4 }
        if q.count == starts.count { score += fullAcronymBonus }
        score -= lengthPenaltyPerChar * max(0, c.count - q.count)
        return Match(score: score, positions: positions)
    }

    private static func subsequence(_ q: [Character], _ c: [Character], wordStarts: Set<Int>) -> [Int]? {
        var positions: [Int] = []
        var from = 0
        for qc in q {
            // Prefer the next word-start occurrence if it's reasonably close; else the first occurrence.
            var chosen: Int? = nil
            var i = from
            var firstPlain: Int? = nil
            while i < c.count {
                if c[i] == qc {
                    if firstPlain == nil { firstPlain = i }
                    if wordStarts.contains(i) { chosen = i; break }
                    if let fp = firstPlain, i - fp > 6 { break }   // don't hunt too far for a word start
                }
                i += 1
            }
            guard let pos = chosen ?? firstPlain else { return nil }
            // If the plain hit is immediately consecutive with the previous char, prefer it over a far word start.
            if let last = positions.last, let fp = firstPlain, fp == last + 1, pos != fp {
                positions.append(fp); from = fp + 1
            } else {
                positions.append(pos); from = pos + 1
            }
        }
        return positions
    }
}
