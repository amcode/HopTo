import Foundation

/// Remembers what you launch so frequently-used things float up. Persisted as JSON in UserDefaults.
public final class UsageStore {
    public struct Record: Codable, Equatable {
        public var count: Int
        public var lastUsed: Date
    }

    static let key = "usage"
    private let defaults: UserDefaults
    private(set) var records: [String: Record]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([String: Record].self, from: data) {
            records = decoded
        } else {
            records = [:]
        }
    }

    public func record(_ id: String, at date: Date = Date()) {
        var r = records[id] ?? Record(count: 0, lastUsed: date)
        r.count += 1
        r.lastUsed = date
        records[id] = r
        save()
    }

    public func usage(for id: String) -> Record? { records[id] }

    /// Score boost for an item: more launches and more recent launches rank higher.
    /// Deliberately capped so a strong text match always beats habit.
    public func boost(for id: String, now: Date = Date()) -> Int {
        guard let r = records[id] else { return 0 }
        let countPart = min(r.count, 20) * 4                       // up to 80
        let days = max(0, now.timeIntervalSince(r.lastUsed) / 86_400)
        let recencyPart = days < 1 ? 40 : days < 7 ? 20 : days < 30 ? 8 : 0
        return countPart + recencyPart
    }

    /// Items used recently, most recent first — shown before any query is typed.
    public func recent(limit: Int, now: Date = Date()) -> [String] {
        records
            .sorted { a, b in
                if a.value.lastUsed != b.value.lastUsed { return a.value.lastUsed > b.value.lastUsed }
                return a.value.count > b.value.count
            }
            .prefix(limit)
            .map(\.key)
    }

    public func forget(_ id: String) {
        records[id] = nil
        save()
    }

    public func reset() {
        records = [:]
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
