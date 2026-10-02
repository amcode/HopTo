import Foundation

/// Known System Settings panes on macOS 13+, with the words people actually type for them.
/// The app also discovers panes from disk; this catalogue supplies friendly names and keywords,
/// and guarantees the common ones exist even if discovery fails.
public enum SettingsCatalogue {
    public struct Pane: Equatable {
        public let id: String        // the ExtensionKit bundle identifier used in the URL
        public let name: String
        public let keywords: [String]
    }

    public static let urlScheme = "x-apple.systempreferences:"

    public static func url(for pane: Pane) -> URL {
        URL(string: urlScheme + pane.id)!
    }

    public static func url(forPaneID id: String) -> URL? {
        URL(string: urlScheme + id)
    }

    public static let panes: [Pane] = [
        Pane(id: "com.apple.wifi-settings-extension", name: "Wi‑Fi", keywords: ["wifi", "wireless", "network", "internet"]),
        Pane(id: "com.apple.BluetoothSettings", name: "Bluetooth", keywords: ["bt", "airpods", "headphones"]),
        Pane(id: "com.apple.Network-Settings.extension", name: "Network", keywords: ["ethernet", "vpn", "dns", "firewall"]),
        Pane(id: "com.apple.Battery-Settings.extension", name: "Battery", keywords: ["power", "energy", "charge", "low power mode"]),
        Pane(id: "com.apple.systempreferences.GeneralSettings", name: "General", keywords: ["about", "software update", "startup disk", "login items", "airdrop", "handoff"]),
        Pane(id: "com.apple.Appearance-Settings.extension", name: "Appearance", keywords: ["dark mode", "light mode", "theme", "accent colour", "accent color"]),
        Pane(id: "com.apple.Accessibility-Settings.extension", name: "Accessibility", keywords: ["zoom", "voiceover", "contrast", "pointer size"]),
        Pane(id: "com.apple.ControlCenter-Settings.extension", name: "Control Centre", keywords: ["control center", "menu bar", "menubar"]),
        Pane(id: "com.apple.Siri-Settings.extension", name: "Siri & Spotlight", keywords: ["siri", "spotlight", "search"]),
        Pane(id: "com.apple.settings.PrivacySecurity.extension", name: "Privacy & Security", keywords: ["privacy", "security", "permissions", "filevault", "gatekeeper", "input monitoring", "accessibility permission", "camera", "microphone"]),
        Pane(id: "com.apple.Desktop-Settings.extension", name: "Desktop & Dock", keywords: ["dock", "wallpaper", "hot corners", "stage manager", "mission control"]),
        Pane(id: "com.apple.Displays-Settings.extension", name: "Displays", keywords: ["screen", "monitor", "resolution", "brightness", "night shift", "true tone"]),
        Pane(id: "com.apple.Wallpaper-Settings.extension", name: "Wallpaper", keywords: ["background", "desktop picture"]),
        Pane(id: "com.apple.ScreenSaver-Settings.extension", name: "Screen Saver", keywords: ["screensaver"]),
        Pane(id: "com.apple.Notifications-Settings.extension", name: "Notifications", keywords: ["alerts", "banners", "do not disturb", "focus"]),
        Pane(id: "com.apple.Sound-Settings.extension", name: "Sound", keywords: ["audio", "volume", "output", "input", "speakers", "microphone"]),
        Pane(id: "com.apple.Focus-Settings.extension", name: "Focus", keywords: ["do not disturb", "dnd"]),
        Pane(id: "com.apple.Screen-Time-Settings.extension", name: "Screen Time", keywords: ["limits", "downtime"]),
        Pane(id: "com.apple.Lock-Screen-Settings.extension", name: "Lock Screen", keywords: ["lock", "login window", "sleep"]),
        Pane(id: "com.apple.Touch-ID-Settings.extension", name: "Touch ID & Password", keywords: ["touch id", "touchid", "fingerprint", "password"]),
        Pane(id: "com.apple.Users-Groups-Settings.extension", name: "Users & Groups", keywords: ["accounts", "users", "guest"]),
        Pane(id: "com.apple.Internet-Accounts-Settings.extension", name: "Internet Accounts", keywords: ["mail", "icloud", "google", "exchange"]),
        Pane(id: "com.apple.Passwords-Settings.extension", name: "Passwords", keywords: ["keychain", "passkeys"]),
        Pane(id: "com.apple.Keyboard-Settings.extension", name: "Keyboard", keywords: ["shortcuts", "input sources", "text replacement", "dictation", "function keys"]),
        Pane(id: "com.apple.Trackpad-Settings.extension", name: "Trackpad", keywords: ["gestures", "tap to click", "scroll direction"]),
        Pane(id: "com.apple.Mouse-Settings.extension", name: "Mouse", keywords: ["tracking speed", "scroll"]),
        Pane(id: "com.apple.Print-Scan-Settings.extension", name: "Printers & Scanners", keywords: ["printer", "scanner", "print"]),
        Pane(id: "com.apple.Game-Controller-Settings.extension", name: "Game Controllers", keywords: ["controller", "gamepad"]),
        Pane(id: "com.apple.Date-Time-Settings.extension", name: "Date & Time", keywords: ["clock", "time zone", "timezone"]),
        Pane(id: "com.apple.Localization-Settings.extension", name: "Language & Region", keywords: ["language", "region", "locale"]),
        Pane(id: "com.apple.Sharing-Settings.extension", name: "Sharing", keywords: ["screen sharing", "file sharing", "remote login", "ssh", "hostname"]),
        Pane(id: "com.apple.Time-Machine-Settings.extension", name: "Time Machine", keywords: ["backup", "backups"]),
        Pane(id: "com.apple.Transfer-Reset-Settings.extension", name: "Transfer or Reset", keywords: ["erase", "migration", "reset"]),
        Pane(id: "com.apple.Startup-Disk-Settings.extension", name: "Startup Disk", keywords: ["boot"]),
        Pane(id: "com.apple.systempreferences.AppleIDSettings", name: "Apple ID", keywords: ["icloud", "apple account", "account"]),
        Pane(id: "com.apple.Extensions-Settings.extension", name: "Extensions", keywords: ["quick actions", "share menu"]),
        Pane(id: "com.apple.Software-Update-Settings.extension", name: "Software Update", keywords: ["update", "updates", "macos update"]),
        Pane(id: "com.apple.CD-DVD-Settings.extension", name: "CDs & DVDs", keywords: ["disc"]),
    ]

    /// The catalogue as searchable items.
    public static var hops: [Hop] {
        panes.map { Hop(id: $0.id, name: $0.name, kind: .settings, keywords: $0.keywords + ["settings", "preferences", "prefs", "system settings"]) }
    }

    public static func pane(withID id: String) -> Pane? {
        panes.first { $0.id == id }
    }
}
