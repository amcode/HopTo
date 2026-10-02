import XCTest
@testable import HopToCore

func makeTestDefaults(_ name: String = #function) -> UserDefaults {
    let suite = "HopToTests.\(name).\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    return d
}

final class SearchEngineTests: XCTestCase {
    private var defaults: UserDefaults!
    private var usage: UsageStore!
    private var engine: SearchEngine!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private let apps: [Hop] = [
        Hop(id: "/Applications/Safari.app", name: "Safari", kind: .app, path: "/Applications/Safari.app"),
        Hop(id: "/Applications/Slack.app", name: "Slack", kind: .app, path: "/Applications/Slack.app"),
        Hop(id: "/System/Applications/Utilities/Terminal.app", name: "Terminal", kind: .app),
        Hop(id: "/System/Applications/TextEdit.app", name: "TextEdit", kind: .app),
        Hop(id: "/Applications/Visual Studio Code.app", name: "Visual Studio Code", kind: .app, keywords: ["vscode", "code"]),
        Hop(id: "/System/Applications/Utilities/Activity Monitor.app", name: "Activity Monitor", kind: .app),
        Hop(id: "/System/Applications/Mail.app", name: "Mail", kind: .app),
        Hop(id: "/System/Applications/Messages.app", name: "Messages", kind: .app),
        Hop(id: "/System/Applications/Music.app", name: "Music", kind: .app),
        Hop(id: "/System/Applications/System Settings.app", name: "System Settings", kind: .app, keywords: ["preferences"]),
    ]

    override func setUp() {
        super.setUp()
        defaults = makeTestDefaults()
        usage = UsageStore(defaults: defaults)
        engine = SearchEngine(usage: usage)
        engine.setIndex(apps + SettingsCatalogue.hops)
    }

    private func names(_ q: String) -> [String] { engine.search(q, now: now).map(\.hop.name) }

    // MARK: Index

    func testIndexCountsAndDeduplicates() {
        XCTAssertEqual(engine.count, apps.count + SettingsCatalogue.panes.count)
        engine.setIndex(apps + apps)
        XCTAssertEqual(engine.count, apps.count)
    }

    func testHopLookupByID() {
        XCTAssertEqual(engine.hop(withID: "/Applications/Safari.app")?.name, "Safari")
        XCTAssertNil(engine.hop(withID: "nope"))
    }

    // MARK: Searching

    func testPrefixQueryFindsApp() {
        XCTAssertEqual(names("saf").first, "Safari")
    }

    func testResultsLimited() {
        engine.limit = 3
        XCTAssertLessThanOrEqual(engine.search("s", now: now).count, 3)
    }

    func testDefaultLimitIsEight() {
        XCTAssertEqual(SearchEngine.defaultLimit, 8)
        XCTAssertLessThanOrEqual(engine.search("e", now: now).count, 8)
    }

    func testNoMatchGivesEmpty() {
        XCTAssertTrue(engine.search("zzzzqqq", now: now).isEmpty)
    }

    func testWhitespaceTrimmed() {
        XCTAssertEqual(names("  saf  ").first, "Safari")
    }

    func testKeywordFindsVSCode() {
        XCTAssertEqual(names("vscode").first, "Visual Studio Code")
    }

    func testSettingsPaneFoundByKeyword() {
        XCTAssertEqual(names("wifi").first, "Wi‑Fi")
        XCTAssertEqual(names("dark mode").first, "Appearance")
        XCTAssertEqual(names("bluetooth").first, "Bluetooth")
    }

    func testAppBeatsSettingsPaneForAppName() {
        XCTAssertEqual(names("terminal").first, "Terminal")
    }

    func testExactNameGoesFirst() {
        XCTAssertEqual(names("mail").first, "Mail")
        XCTAssertEqual(names("music").first, "Music")
    }

    func testAcronymsWork() {
        XCTAssertEqual(names("am").first, "Activity Monitor")
        XCTAssertEqual(names("vsc").first, "Visual Studio Code")
    }

    func testPrefixBeatsAcronymForSlack() {
        XCTAssertEqual(names("sl").first, "Slack")
    }

    func testPositionsReturnedForHighlighting() {
        let r = engine.search("saf", now: now).first!
        XCTAssertEqual(r.positions, [0, 1, 2])
    }

    func testResultsSortedByScoreDescending() {
        let scores = engine.search("s", now: now).map(\.score)
        XCTAssertEqual(scores, scores.sorted(by: >))
    }

    func testTieBreakPrefersShorterName() {
        engine.setIndex([
            Hop(id: "a", name: "Note Taker", kind: .app),
            Hop(id: "b", name: "Note", kind: .app),
        ])
        // Both exact-prefix; shorter wins (also higher score due to length penalty).
        XCTAssertEqual(names("note").first, "Note")
    }

    // MARK: Usage boosts ranking

    func testLaunchingBoostsFutureRank() {
        // "te" ties Terminal and TextEdit on text score.
        let before = names("te")
        XCTAssertEqual(Set(before.prefix(2)), ["Terminal", "TextEdit"])
        let textEdit = engine.hop(withID: "/System/Applications/TextEdit.app")!
        engine.didLaunch(textEdit, at: now)
        XCTAssertEqual(names("te").first, "TextEdit")
    }

    func testUsageCannotOverrideStrongTextMatch() {
        let slack = engine.hop(withID: "/Applications/Slack.app")!
        for _ in 0..<50 { engine.didLaunch(slack, at: now) }
        XCTAssertEqual(names("safari").first, "Safari", "exact match must beat habit")
    }

    func testUsageBreaksNearTies() {
        let monitor = engine.hop(withID: "/System/Applications/Utilities/Activity Monitor.app")!
        engine.didLaunch(monitor, at: now)
        XCTAssertEqual(names("a").first, "Activity Monitor")
    }

    // MARK: Empty query → recent

    func testEmptyQueryIsEmptyWithNoHistory() {
        XCTAssertTrue(engine.search("", now: now).isEmpty)
    }

    func testEmptyQueryShowsRecentMostRecentFirst() {
        engine.didLaunch(apps[0], at: now.addingTimeInterval(-100))
        engine.didLaunch(apps[1], at: now.addingTimeInterval(-10))
        engine.didLaunch(apps[2], at: now.addingTimeInterval(-50))
        XCTAssertEqual(names(""), ["Slack", "Terminal", "Safari"])
    }

    func testRecentSkipsItemsNoLongerIndexed() {
        engine.didLaunch(apps[0], at: now)
        engine.setIndex([apps[1]])
        XCTAssertTrue(engine.search("", now: now).isEmpty)
    }

    func testRecentRespectsLimit() {
        engine.limit = 2
        for (i, a) in apps.prefix(5).enumerated() { engine.didLaunch(a, at: now.addingTimeInterval(Double(i))) }
        XCTAssertEqual(engine.search("", now: now).count, 2)
    }
}

final class UsageStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: UsageStore!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        defaults = makeTestDefaults()
        store = UsageStore(defaults: defaults)
    }

    func testStartsEmpty() {
        XCTAssertNil(store.usage(for: "x"))
        XCTAssertEqual(store.boost(for: "x", now: now), 0)
        XCTAssertTrue(store.recent(limit: 5, now: now).isEmpty)
    }

    func testRecordIncrementsAndStampsDate() {
        store.record("x", at: now)
        store.record("x", at: now.addingTimeInterval(5))
        XCTAssertEqual(store.usage(for: "x")?.count, 2)
        XCTAssertEqual(store.usage(for: "x")?.lastUsed, now.addingTimeInterval(5))
    }

    func testPersistsAcrossInstances() {
        store.record("x", at: now)
        let again = UsageStore(defaults: defaults)
        XCTAssertEqual(again.usage(for: "x")?.count, 1)
    }

    func testBoostGrowsWithCount() {
        store.record("x", at: now)
        let one = store.boost(for: "x", now: now)
        for _ in 0..<4 { store.record("x", at: now) }
        XCTAssertGreaterThan(store.boost(for: "x", now: now), one)
    }

    func testBoostIsCapped() {
        for _ in 0..<1000 { store.record("x", at: now) }
        XCTAssertLessThanOrEqual(store.boost(for: "x", now: now), 120)
    }

    func testBoostDecaysWithAge() {
        store.record("x", at: now)
        let fresh = store.boost(for: "x", now: now)
        let week = store.boost(for: "x", now: now.addingTimeInterval(8 * 86_400))
        let old = store.boost(for: "x", now: now.addingTimeInterval(60 * 86_400))
        XCTAssertGreaterThan(fresh, week)
        XCTAssertGreaterThan(week, old)
    }

    func testRecentOrdersByLastUsed() {
        store.record("a", at: now)
        store.record("b", at: now.addingTimeInterval(10))
        store.record("c", at: now.addingTimeInterval(-10))
        XCTAssertEqual(store.recent(limit: 10, now: now), ["b", "a", "c"])
    }

    func testRecentLimit() {
        for i in 0..<10 { store.record("\(i)", at: now.addingTimeInterval(Double(i))) }
        XCTAssertEqual(store.recent(limit: 3, now: now).count, 3)
    }

    func testForgetRemovesOne() {
        store.record("a", at: now); store.record("b", at: now)
        store.forget("a")
        XCTAssertNil(store.usage(for: "a"))
        XCTAssertNotNil(store.usage(for: "b"))
    }

    func testResetClearsAllAndPersists() {
        store.record("a", at: now)
        store.reset()
        XCTAssertTrue(UsageStore(defaults: defaults).recent(limit: 5, now: now).isEmpty)
    }

    func testCorruptDataStartsEmpty() {
        defaults.set(Data([0x01, 0x02]), forKey: UsageStore.key)
        XCTAssertTrue(UsageStore(defaults: defaults).recent(limit: 5, now: now).isEmpty)
    }
}
