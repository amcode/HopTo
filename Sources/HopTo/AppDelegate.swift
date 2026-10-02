import AppKit
import ServiceManagement
import HopToCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let settings = Settings()
    private lazy var usage = UsageStore()
    private lazy var engine = SearchEngine(usage: usage)
    private lazy var panel = LauncherPanel(engine: engine)
    private let hotKey = HotKeyRegistrar()
    private var rescanTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "arrow.up.right.circle", accessibilityDescription: "Hop To")
        image?.isTemplate = true
        statusItem.button?.image = image
        rebuildMenu()

        panel.onChoose = { [weak self] hop in self?.launch(hop) }
        registerHotKey()
        reindex()

        // Apps get installed and removed; keep the index fresh without a file watcher.
        rescanTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.reindex() }
    }

    // MARK: Index

    private func reindex() {
        let folders = settings.appFolders
        let includeSettings = settings.includeSettings
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var items = Indexer.scanApps(folders: folders)
            if includeSettings { items += Indexer.scanSettings() }
            DispatchQueue.main.async { self?.engine.setIndex(items) }
        }
    }

    // MARK: Launch

    private func launch(_ hop: Hop) {
        engine.didLaunch(hop)
        switch hop.kind {
        case .app:
            guard let path = hop.path else { return }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config)
        case .settings:
            if let url = SettingsCatalogue.url(forPaneID: hop.id) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: Hot key

    private func registerHotKey() {
        hotKey.register(settings.hotKey) { [weak self] in self?.panel.toggle() }
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open Hop To", action: #selector(showPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let keyMenu = NSMenu()
        for hk in HotKey.presets {
            let item = NSMenuItem(title: hk.displayName, action: #selector(setHotKey(_:)), keyEquivalent: "")
            item.representedObject = try? JSONEncoder().encode(hk)
            item.target = self
            item.state = hk == settings.hotKey ? .on : .off
            keyMenu.addItem(item)
        }
        let keyItem = NSMenuItem(title: "Shortcut", action: nil, keyEquivalent: "")
        keyItem.submenu = keyMenu
        menu.addItem(keyItem)

        let incl = NSMenuItem(title: "Include System Settings", action: #selector(toggleSettings), keyEquivalent: "")
        incl.target = self
        incl.state = settings.includeSettings ? .on : .off
        menu.addItem(incl)

        let folder = NSMenuItem(title: "Add an app folder…", action: #selector(addFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)

        let rescan = NSMenuItem(title: "Rescan apps now", action: #selector(rescanNow), keyEquivalent: "")
        rescan.target = self
        menu.addItem(rescan)

        let forget = NSMenuItem(title: "Forget launch history", action: #selector(forgetHistory), keyEquivalent: "")
        forget.target = self
        menu.addItem(forget)

        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let about = NSMenuItem(title: "About Hop To", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: "Quit Hop To", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: Actions

    @objc private func showPanel() { panel.show() }

    @objc private func setHotKey(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? Data,
              let hk = try? JSONDecoder().decode(HotKey.self, from: data) else { return }
        settings.hotKey = hk
        registerHotKey()
        rebuildMenu()
    }

    @objc private func toggleSettings() {
        settings.includeSettings.toggle()
        rebuildMenu()
        reindex()
    }

    @objc private func addFolder() {
        let dialog = NSOpenPanel()
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        dialog.prompt = "Add"
        NSApp.activate(ignoringOtherApps: true)
        if dialog.runModal() == .OK, let url = dialog.url {
            settings.extraAppFolders.append(url.path)
            reindex()
        }
    }

    @objc private func rescanNow() { reindex() }

    @objc private func forgetHistory() { usage.reset() }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login failed: \(error)")
        }
        rebuildMenu()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Hop To"
        alert.informativeText = "Press \(settings.hotKey.displayName), type a few letters, press Return.\n\nLaunches apps and opens System Settings panes. Nothing else."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
