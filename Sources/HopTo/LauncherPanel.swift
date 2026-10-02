import AppKit
import HopToCore

/// The floating search panel: a text field on top, results beneath. Keyboard-driven.
final class LauncherPanel: NSPanel, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let engine: SearchEngine
    private let field = NSTextField()
    private let table = NSTableView()
    private let scroll = NSScrollView()
    private var results: [SearchEngine.Result] = []
    var onChoose: ((Hop) -> Void)?

    private let rowHeight: CGFloat = 46
    private let panelWidth: CGFloat = 620
    private let fieldHeight: CGFloat = 58

    init(engine: SearchEngine) {
        self.engine = engine
        super.init(contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: fieldHeight),
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        backgroundColor = .clear
        isOpaque = false

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        contentView = effect

        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 26, weight: .light)
        field.placeholderString = "Hop to…"
        field.delegate = self
        field.cell?.sendsActionOnEndEditing = false
        field.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(field)

        table.dataSource = self
        table.delegate = self
        table.headerView = nil
        table.rowHeight = rowHeight
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.intercellSpacing = .zero
        table.addTableColumn(NSTableColumn(identifier: .init("main")))
        table.target = self
        table.action = #selector(rowClicked)
        scroll.documentView = table
        scroll.hasVerticalScroller = false
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(scroll)

        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            field.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
            field.topAnchor.constraint(equalTo: effect.topAnchor, constant: 14),
            field.heightAnchor.constraint(equalToConstant: 34),
            scroll.topAnchor.constraint(equalTo: effect.topAnchor, constant: fieldHeight),
            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -8),
        ])
    }

    override var canBecomeKey: Bool { true }

    // MARK: Show / hide

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        field.stringValue = ""
        refresh()
        centreOnActiveScreen()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        makeFirstResponder(field)
    }

    func hide() {
        orderOut(nil)
    }

    private func centreOnActiveScreen() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let x = frame.midX - panelWidth / 2
        let y = frame.minY + frame.height * 0.62
        setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    private func resize() {
        let rows = CGFloat(results.count)
        let height = fieldHeight + (rows > 0 ? rows * rowHeight + 16 : 0)
        var f = frame
        let top = f.maxY
        f.size.height = height
        f.origin.y = top - height
        setFrame(f, display: true, animate: false)
    }

    // MARK: Search

    private func refresh() {
        results = engine.search(field.stringValue)
        table.reloadData()
        if !results.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
        resize()
    }

    func controlTextDidChange(_ obj: Notification) { refresh() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            move(by: 1); return true
        case #selector(NSResponder.moveUp(_:)):
            move(by: -1); return true
        case #selector(NSResponder.insertNewline(_:)):
            chooseSelected(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            hide(); return true
        default:
            return false
        }
    }

    override func keyDown(with event: NSEvent) {
        // ⌘1…⌘9 picks a row directly.
        if event.modifierFlags.contains(.command), let ch = event.charactersIgnoringModifiers,
           let n = Int(ch), n >= 1, n <= results.count {
            choose(results[n - 1].hop); return
        }
        super.keyDown(with: event)
    }

    private func move(by delta: Int) {
        guard !results.isEmpty else { return }
        let next = (table.selectedRow + delta + results.count) % results.count
        table.selectRowIndexes([next], byExtendingSelection: false)
        table.scrollRowToVisible(next)
    }

    private func chooseSelected() {
        guard table.selectedRow >= 0, table.selectedRow < results.count else { return }
        choose(results[table.selectedRow].hop)
    }

    @objc private func rowClicked() {
        chooseSelected()
    }

    private func choose(_ hop: Hop) {
        hide()
        onChoose?(hop)
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let r = results[row]
        let cell = NSTableCellView()

        let icon = NSImageView(image: Indexer.icon(for: r.hop))
        icon.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithAttributedString: highlighted(r))
        title.translatesAutoresizingMaskIntoConstraints = false
        let subtitle = NSTextField(labelWithString: r.hop.subtitle)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        let hint = NSTextField(labelWithString: row < 9 ? "⌘\(row + 1)" : "")
        hint.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        hint.textColor = .tertiaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        [icon, title, subtitle, hint].forEach(cell.addSubview)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 6),
            title.trailingAnchor.constraint(lessThanOrEqualTo: hint.leadingAnchor, constant: -8),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
            hint.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -14),
            hint.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let v = NSTableRowView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 8
        return v
    }

    private func highlighted(_ r: SearchEngine.Result) -> NSAttributedString {
        let s = NSMutableAttributedString(string: r.hop.name, attributes: [
            .font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.labelColor,
        ])
        let chars = Array(r.hop.name)
        for p in r.positions where p < chars.count {
            // positions refer to the normalised string, which has the same length for plain names
            s.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .bold), range: NSRange(location: p, length: 1))
        }
        return s
    }
}
