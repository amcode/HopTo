import Foundation

/// Ties the index, matcher and usage history together: query in, ranked results out.
public final class SearchEngine {
    public struct Result: Equatable {
        public let hop: Hop
        public let score: Int
        public let positions: [Int]
    }

    public static let defaultLimit = 8

    private(set) var hops: [Hop] = []
    private let usage: UsageStore
    public var limit: Int

    public init(usage: UsageStore, limit: Int = SearchEngine.defaultLimit) {
        self.usage = usage
        self.limit = limit
    }

    /// Replace the index. Items with the same id are de-duplicated (first wins).
    public func setIndex(_ items: [Hop]) {
        var seen = Set<String>()
        hops = items.filter { seen.insert($0.id).inserted }
    }

    public var count: Int { hops.count }

    public func hop(withID id: String) -> Hop? { hops.first { $0.id == id } }

    /// Ranked results for a query. An empty query returns recently used items.
    public func search(_ query: String, now: Date = Date()) -> [Result] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return recent(now: now) }

        var results: [Result] = []
        results.reserveCapacity(hops.count)
        for hop in hops {
            guard let m = Matcher.match(query: trimmed, hop: hop) else { continue }
            let score = m.score + usage.boost(for: hop.id, now: now)
            results.append(Result(hop: hop, score: score, positions: m.positions))
        }
        results.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            if a.hop.name.count != b.hop.name.count { return a.hop.name.count < b.hop.name.count }
            return a.hop.name < b.hop.name
        }
        return Array(results.prefix(limit))
    }

    /// Record a launch so it ranks higher next time.
    public func didLaunch(_ hop: Hop, at date: Date = Date()) {
        usage.record(hop.id, at: date)
    }

    private func recent(now: Date) -> [Result] {
        usage.recent(limit: limit, now: now)
            .compactMap { id in hop(withID: id) }
            .map { Result(hop: $0, score: 0, positions: []) }
    }
}
