import Foundation

/// A global keyboard shortcut, expressed without AppKit so it can be stored and tested.
public struct HotKey: Equatable, Codable {
    public struct Modifiers: OptionSet, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option  = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift   = Modifiers(rawValue: 1 << 3)
    }

    /// macOS virtual key code (kVK_*). Space is 49.
    public let keyCode: UInt32
    public let modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let space: UInt32 = 49

    /// Offered in the menu. ⌘Space is deliberately absent: that's Spotlight.
    public static let presets: [HotKey] = [
        HotKey(keyCode: space, modifiers: [.option]),
        HotKey(keyCode: space, modifiers: [.control]),
        HotKey(keyCode: space, modifiers: [.command, .option]),
        HotKey(keyCode: space, modifiers: [.command, .shift]),
        HotKey(keyCode: space, modifiers: [.control, .option]),
    ]

    public static let `default` = presets[0]

    /// "⌥ Space", in the order macOS shows modifiers.
    public var displayName: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined(separator: " ")
    }

    private var keyName: String {
        keyCode == Self.space ? "Space" : "Key \(keyCode)"
    }
}

/// User settings, persisted in UserDefaults. Injectable suite so tests stay isolated.
public final class Settings {
    enum Key {
        static let hotKey = "hotKey"
        static let includeSettings = "includeSettings"
        static let extraAppFolders = "extraAppFolders"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hotKey: HotKey {
        get {
            if let data = defaults.data(forKey: Key.hotKey),
               let hk = try? JSONDecoder().decode(HotKey.self, from: data) {
                return hk
            }
            return .default
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.hotKey) }
    }

    /// Whether System Settings panes appear in results. On by default.
    public var includeSettings: Bool {
        get { defaults.object(forKey: Key.includeSettings) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.includeSettings) }
    }

    /// Additional folders to scan for apps, on top of the standard ones.
    public var extraAppFolders: [String] {
        get { defaults.stringArray(forKey: Key.extraAppFolders) ?? [] }
        set { defaults.set(newValue, forKey: Key.extraAppFolders) }
    }

    /// The folders macOS keeps apps in.
    public static let standardAppFolders: [String] = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        "/System/Library/CoreServices/Applications",
        NSHomeDirectory() + "/Applications",
    ]

    public var appFolders: [String] {
        var seen = Set<String>()
        return (Self.standardAppFolders + extraAppFolders).filter { seen.insert($0).inserted }
    }
}
