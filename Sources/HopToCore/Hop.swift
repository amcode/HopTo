import Foundation

/// Something the user can hop to: an app or a System Settings pane.
public struct Hop: Equatable, Hashable, Identifiable, Codable {
    public enum Kind: String, Codable {
        case app
        case settings
    }

    /// Stable identity: the bundle path for apps, the pane identifier for settings.
    public let id: String
    public let name: String
    public let kind: Kind
    /// Extra words that should match this item ("wifi" for "Wi-Fi", "prefs" for System Settings…).
    public let keywords: [String]
    /// Where it lives on disk (apps) — used for the icon.
    public let path: String?

    public init(id: String, name: String, kind: Kind, keywords: [String] = [], path: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.keywords = keywords
        self.path = path
    }

    public var subtitle: String {
        switch kind {
        case .app: return "Application"
        case .settings: return "System Settings"
        }
    }
}
