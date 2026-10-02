import XCTest
@testable import HopToCore

final class SettingsCatalogueTests: XCTestCase {
    func testPaneIDsAreUnique() {
        let ids = SettingsCatalogue.panes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testPaneNamesAreUnique() {
        let names = SettingsCatalogue.panes.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testEveryPaneHasAName() {
        XCTAssertTrue(SettingsCatalogue.panes.allSatisfy { !$0.name.isEmpty })
    }

    func testURLsUseSystemPreferencesScheme() {
        for pane in SettingsCatalogue.panes {
            let url = SettingsCatalogue.url(for: pane)
            XCTAssertEqual(url.scheme, "x-apple.systempreferences")
            XCTAssertTrue(url.absoluteString.hasSuffix(pane.id))
        }
    }

    func testURLForID() {
        XCTAssertEqual(SettingsCatalogue.url(forPaneID: "com.apple.BluetoothSettings")?.absoluteString,
                       "x-apple.systempreferences:com.apple.BluetoothSettings")
    }

    func testHopsCarryGenericSettingsKeywords() {
        for hop in SettingsCatalogue.hops {
            XCTAssertEqual(hop.kind, .settings)
            XCTAssertTrue(hop.keywords.contains("settings"))
            XCTAssertTrue(hop.keywords.contains("preferences"))
        }
    }

    func testHopsKeepPaneKeywords() {
        let wifi = SettingsCatalogue.hops.first { $0.name == "Wi‑Fi" }!
        XCTAssertTrue(wifi.keywords.contains("wifi"))
    }

    func testLookupByID() {
        XCTAssertEqual(SettingsCatalogue.pane(withID: "com.apple.Sound-Settings.extension")?.name, "Sound")
        XCTAssertNil(SettingsCatalogue.pane(withID: "nope"))
    }

    func testCommonPanesExist() {
        let names = Set(SettingsCatalogue.panes.map(\.name))
        for expected in ["Wi‑Fi", "Bluetooth", "Displays", "Sound", "Keyboard", "Privacy & Security", "General"] {
            XCTAssertTrue(names.contains(expected), expected)
        }
    }

    func testKeywordsAreLowercase() {
        for pane in SettingsCatalogue.panes {
            for k in pane.keywords { XCTAssertEqual(k, k.lowercased(), "\(pane.name): \(k)") }
        }
    }
}

final class HotKeyTests: XCTestCase {
    func testDefaultIsOptionSpace() {
        XCTAssertEqual(HotKey.default, HotKey(keyCode: HotKey.space, modifiers: [.option]))
        XCTAssertEqual(HotKey.default.displayName, "⌥ Space")
    }

    func testPresetsAreUnique() {
        let names = HotKey.presets.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testCommandSpaceIsNotOffered() {
        XCTAssertFalse(HotKey.presets.contains(HotKey(keyCode: HotKey.space, modifiers: [.command])))
    }

    func testDisplayNameOrdersModifiersLikeMacOS() {
        let hk = HotKey(keyCode: HotKey.space, modifiers: [.command, .shift, .option, .control])
        XCTAssertEqual(hk.displayName, "⌃ ⌥ ⇧ ⌘ Space")
    }

    func testUnknownKeyCodeShowsNumber() {
        XCTAssertEqual(HotKey(keyCode: 36, modifiers: []).displayName, "Key 36")
    }

    func testCodableRoundTrip() throws {
        for hk in HotKey.presets {
            let data = try JSONEncoder().encode(hk)
            XCTAssertEqual(try JSONDecoder().decode(HotKey.self, from: data), hk)
        }
    }
}

final class SettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: Settings!

    override func setUp() {
        super.setUp()
        defaults = makeTestDefaults()
        settings = Settings(defaults: defaults)
    }

    func testDefaults() {
        XCTAssertEqual(settings.hotKey, .default)
        XCTAssertTrue(settings.includeSettings)
        XCTAssertTrue(settings.extraAppFolders.isEmpty)
    }

    func testHotKeyRoundTrips() {
        let hk = HotKey.presets[2]
        settings.hotKey = hk
        XCTAssertEqual(Settings(defaults: defaults).hotKey, hk)
    }

    func testCorruptHotKeyFallsBackToDefault() {
        defaults.set(Data([0xFF]), forKey: Settings.Key.hotKey)
        XCTAssertEqual(settings.hotKey, .default)
    }

    func testIncludeSettingsRoundTrips() {
        settings.includeSettings = false
        XCTAssertFalse(Settings(defaults: defaults).includeSettings)
    }

    func testExtraFoldersRoundTrip() {
        settings.extraAppFolders = ["/Users/me/Dev/Apps"]
        XCTAssertEqual(Settings(defaults: defaults).extraAppFolders, ["/Users/me/Dev/Apps"])
    }

    func testAppFoldersIncludesStandardAndExtra() {
        settings.extraAppFolders = ["/Extra"]
        let folders = settings.appFolders
        XCTAssertTrue(folders.contains("/Applications"))
        XCTAssertTrue(folders.contains("/System/Applications"))
        XCTAssertEqual(folders.last, "/Extra")
    }

    func testAppFoldersDeduplicates() {
        settings.extraAppFolders = ["/Applications", "/Applications"]
        let folders = settings.appFolders
        XCTAssertEqual(folders.filter { $0 == "/Applications" }.count, 1)
    }

    func testStandardFoldersIncludeUserApplications() {
        XCTAssertTrue(Settings.standardAppFolders.contains { $0.hasSuffix("/Applications") && $0.hasPrefix(NSHomeDirectory()) })
    }
}

final class HopTests: XCTestCase {
    func testSubtitles() {
        XCTAssertEqual(Hop(id: "a", name: "A", kind: .app).subtitle, "Application")
        XCTAssertEqual(Hop(id: "b", name: "B", kind: .settings).subtitle, "System Settings")
    }

    func testIdentityIsID() {
        let a = Hop(id: "same", name: "One", kind: .app)
        let b = Hop(id: "same", name: "Two", kind: .app)
        XCTAssertEqual(a.id, b.id)
        XCTAssertNotEqual(a, b)
    }

    func testCodableRoundTrip() throws {
        let hop = Hop(id: "/x.app", name: "X", kind: .app, keywords: ["y"], path: "/x.app")
        let data = try JSONEncoder().encode(hop)
        XCTAssertEqual(try JSONDecoder().decode(Hop.self, from: data), hop)
    }
}
