import AppKit
import Foundation
import HopToCore

/// Finds apps and System Settings panes on disk and turns them into `Hop`s.
enum Indexer {
    /// Scans the given folders (one level deep, plus one more for app sub-folders) for .app bundles.
    static func scanApps(folders: [String]) -> [Hop] {
        let fm = FileManager.default
        var hops: [Hop] = []
        for folder in folders {
            guard let entries = try? fm.contentsOfDirectory(atPath: folder) else { continue }
            for entry in entries {
                let path = (folder as NSString).appendingPathComponent(entry)
                if entry.hasSuffix(".app") {
                    hops.append(appHop(at: path))
                } else if isPlainDirectory(path) {
                    // e.g. /Applications/Adobe Creative Cloud/… — one level only.
                    if let sub = try? fm.contentsOfDirectory(atPath: path) {
                        for e in sub where e.hasSuffix(".app") {
                            hops.append(appHop(at: (path as NSString).appendingPathComponent(e)))
                        }
                    }
                }
            }
        }
        return hops
    }

    private static func isPlainDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return false }
        return !path.hasSuffix(".app") && !path.hasSuffix(".bundle")
    }

    private static func appHop(at path: String) -> Hop {
        let name = FileManager.default.displayName(atPath: path)
            .replacingOccurrences(of: ".app", with: "")
        var keywords: [String] = []
        if let bundle = Bundle(path: path) {
            if let display = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, display != name {
                keywords.append(display)
            }
            if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, bundleName != name {
                keywords.append(bundleName)
            }
        }
        return Hop(id: path, name: name, kind: .app, keywords: keywords, path: path)
    }

    /// System Settings panes: the catalogue, plus anything else found in the ExtensionKit folder.
    static func scanSettings() -> [Hop] {
        var hops = SettingsCatalogue.hops
        var known = Set(hops.map(\.id))
        let dir = "/System/Library/ExtensionKit/Extensions"
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) {
            for entry in entries where entry.hasSuffix(".appex") {
                let path = (dir as NSString).appendingPathComponent(entry)
                guard let bundle = Bundle(path: path),
                      let id = bundle.bundleIdentifier,
                      !known.contains(id),
                      isSettingsExtension(bundle) else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? entry.replacingOccurrences(of: ".appex", with: "")
                hops.append(Hop(id: id, name: name, kind: .settings, keywords: ["settings", "preferences"]))
                known.insert(id)
            }
        }
        return hops
    }

    private static func isSettingsExtension(_ bundle: Bundle) -> Bool {
        guard let ext = bundle.object(forInfoDictionaryKey: "EXAppExtensionAttributes") as? [String: Any],
              let point = ext["EXExtensionPointIdentifier"] as? String else { return false }
        return point == "com.apple.Settings.extension.ui"
    }

    static func icon(for hop: Hop) -> NSImage {
        switch hop.kind {
        case .app:
            return NSWorkspace.shared.icon(forFile: hop.path ?? "")
        case .settings:
            if let settingsApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
                return NSWorkspace.shared.icon(forFile: settingsApp.path)
            }
            return NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) ?? NSImage()
        }
    }
}
