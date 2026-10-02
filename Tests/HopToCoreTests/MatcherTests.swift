import XCTest
@testable import HopToCore

final class MatcherTests: XCTestCase {
    private func score(_ q: String, _ c: String) -> Int? {
        Matcher.match(query: q, in: c)?.score
    }

    // MARK: Basic matching

    func testExactMatchIsTopScore() {
        XCTAssertEqual(score("safari", "Safari"), Matcher.exactBonus)
    }

    func testCaseInsensitive() {
        XCTAssertNotNil(score("SAFARI", "safari"))
        XCTAssertNotNil(score("sAfArI", "Safari"))
    }

    func testDiacriticInsensitive() {
        XCTAssertNotNil(score("cafe", "Café"))
        XCTAssertEqual(score("cafe", "Café"), Matcher.exactBonus)
    }

    func testEmptyQueryMatchesEverythingWithZero() {
        XCTAssertEqual(score("", "Anything"), 0)
        XCTAssertEqual(score("   ", "Anything"), 0)
    }

    func testEmptyCandidateNeverMatches() {
        XCTAssertNil(score("a", ""))
    }

    func testMissingCharacterFails() {
        XCTAssertNil(score("safarix", "Safari"))
        XCTAssertNil(score("xyz", "Safari"))
    }

    func testOutOfOrderCharactersFail() {
        XCTAssertNil(score("rafas", "Safari"))
    }

    func testQueryLongerThanCandidateFails() {
        XCTAssertNil(score("safari browser", "Safari"))
    }

    func testSubsequenceMatches() {
        XCTAssertNotNil(score("sfr", "Safari"))
        XCTAssertNotNil(score("trm", "Terminal"))
    }

    // MARK: Ranking: prefix beats mid-word

    func testPrefixBeatsSubstring() {
        let prefix = score("ter", "Terminal")!
        let mid = score("ter", "Alternate")!
        XCTAssertGreaterThan(prefix, mid)
    }

    func testPrefixBeatsScattered() {
        XCTAssertGreaterThan(score("fin", "Finder")!, score("fin", "Font Information")!)
    }

    func testConsecutiveBeatsGappy() {
        XCTAssertGreaterThan(score("term", "Terminal")!, score("term", "Text Editor Remote")!)
    }

    func testShorterCandidateWinsOnTie() {
        // Both start with "note"; the shorter name should score higher.
        XCTAssertGreaterThan(score("note", "Notes")!, score("note", "Notes Exporter")!)
    }

    // MARK: Word starts and acronyms

    func testWordStartMatchBeatsMidWord() {
        // "ss" → System Settings via word starts should beat "ss" inside "Messages".
        XCTAssertGreaterThan(score("ss", "System Settings")!, score("ss", "Messages")!)
    }

    func testAcronymMatches() {
        let m = Matcher.match(query: "ss", in: "System Settings")!
        XCTAssertEqual(m.positions, [0, 7])
        XCTAssertGreaterThanOrEqual(m.score, Matcher.acronymBonus)
    }

    func testThreeLetterAcronym() {
        XCTAssertNotNil(score("vsc", "Visual Studio Code"))
        XCTAssertEqual(Matcher.match(query: "vsc", in: "Visual Studio Code")!.positions, [0, 7, 14])
    }

    func testAcronymBeatsLooseSubsequence() {
        // "am" as acronym of "Activity Monitor" should beat "am" buried in "Automator".
        XCTAssertGreaterThan(score("am", "Activity Monitor")!, score("am", "Automator")!)
    }

    func testPartialAcronymStillMatches() {
        XCTAssertNotNil(score("vs", "Visual Studio Code"))
    }

    func testHyphenAndPunctuationAreWordBoundaries() {
        XCTAssertNotNil(score("wf", "Wi-Fi"))
        XCTAssertEqual(Matcher.match(query: "wf", in: "Wi-Fi")!.positions, [0, 3])
    }

    func testAmpersandWords() {
        XCTAssertNotNil(score("ps", "Privacy & Security"))
    }

    func testNumbersCountAsWordStarts() {
        XCTAssertTrue(Matcher.wordStartIndices(Array("1Password")).contains(0))
        XCTAssertNotNil(score("1p", "1Password"))
    }

    // MARK: Positions

    func testPositionsAreInOrderAndValid() {
        let m = Matcher.match(query: "sfr", in: "Safari")!
        XCTAssertEqual(m.positions, m.positions.sorted())
        XCTAssertTrue(m.positions.allSatisfy { $0 >= 0 && $0 < 6 })
        XCTAssertEqual(m.positions.count, 3)
    }

    func testExactMatchPositionsCoverWholeString() {
        XCTAssertEqual(Matcher.match(query: "notes", in: "Notes")!.positions, [0, 1, 2, 3, 4])
    }

    func testPrefixPositionsStartAtZero() {
        XCTAssertEqual(Matcher.match(query: "fin", in: "Finder")!.positions, [0, 1, 2])
    }

    // MARK: Real-world launcher cases

    func testTypicalAppQueries() {
        let apps = ["Safari", "System Settings", "Terminal", "Finder", "Mail", "Messages", "Music",
                    "Visual Studio Code", "Activity Monitor", "Xcode", "Slack", "Google Chrome"]
        func top(_ q: String) -> String {
            apps.compactMap { a in Matcher.match(query: q, in: a).map { (a, $0.score) } }
                .max { $0.1 < $1.1 }!.0
        }
        XCTAssertEqual(top("saf"), "Safari")
        XCTAssertEqual(top("term"), "Terminal")
        XCTAssertEqual(top("code"), "Visual Studio Code")
        XCTAssertEqual(top("vsc"), "Visual Studio Code")
        XCTAssertEqual(top("chrome"), "Google Chrome")
        XCTAssertEqual(top("ss"), "System Settings")
        XCTAssertEqual(top("am"), "Activity Monitor")
        XCTAssertEqual(top("mu"), "Music")
        XCTAssertEqual(top("xc"), "Xcode")
    }

    func testMailVsMessagesVsMusic() {
        XCTAssertGreaterThan(score("mai", "Mail")!, score("mai", "Messages") ?? Int.min)
        XCTAssertGreaterThan(score("mes", "Messages")!, score("mes", "Mail") ?? Int.min)
    }

    // MARK: Hop-level matching (name + keywords)

    func testKeywordMatchWorks() {
        let hop = Hop(id: "wifi", name: "Wi‑Fi", kind: .settings, keywords: ["wifi", "wireless"])
        XCTAssertNotNil(Matcher.match(query: "wireless", hop: hop))
    }

    func testKeywordMatchMapsHighlightPositionsToDisplayedName() {
        let hop = Hop(id: "settings", name: "System Settings", kind: .settings, keywords: ["settings"])
        let match = Matcher.match(query: "settings", hop: hop)!
        XCTAssertTrue(match.positions.contains(7))
        XCTAssertTrue(match.positions.contains(14))
        XCTAssertFalse(match.positions.isEmpty)
    }

    func testNameMatchBeatsKeywordMatchOfSameQuality() {
        let byName = Hop(id: "a", name: "Finder", kind: .app)
        let byKeyword = Hop(id: "b", name: "Files", kind: .app, keywords: ["Finder"])
        XCTAssertGreaterThan(Matcher.match(query: "finder", hop: byName)!.score,
                             Matcher.match(query: "finder", hop: byKeyword)!.score)
    }

    func testBestOfNameAndKeywordsIsUsed() {
        let hop = Hop(id: "x", name: "Zzz", kind: .app, keywords: ["Alpha", "Beta"])
        let m = Matcher.match(query: "beta", hop: hop)!
        XCTAssertEqual(m.score, Matcher.exactBonus - 20)
    }

    func testNoMatchOnNameOrKeywords() {
        let hop = Hop(id: "x", name: "Safari", kind: .app, keywords: ["browser"])
        XCTAssertNil(Matcher.match(query: "qqq", hop: hop))
    }

    // MARK: Normalisation / word starts

    func testNormaliseLowercasesAndStripsAccents() {
        XCTAssertEqual(Matcher.normalise("ÉCole"), "ecole")
    }

    func testWordStartIndices() {
        XCTAssertEqual(Matcher.wordStartIndices(Array("System Settings")), [0, 7])
        XCTAssertEqual(Matcher.wordStartIndices(Array("Wi-Fi")), [0, 3])
        XCTAssertEqual(Matcher.wordStartIndices(Array("  x")), [2])
        XCTAssertEqual(Matcher.wordStartIndices(Array("")), [])
    }
}
