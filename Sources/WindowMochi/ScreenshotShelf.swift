import Cocoa
import ImageIO

private final class ShelfDocument: NSView {
    override var isFlipped: Bool { true }
}

private final class ScreenshotSelection: NSObject {
    let checkboxes: [NSButton]
    init(_ checkboxes: [NSButton]) { self.checkboxes = checkboxes; super.init() }
    @objc func selectAll() { checkboxes.forEach { $0.state = .on } }
    @objc func deselectAll() { checkboxes.forEach { $0.state = .off } }
}

private final class ShelfThumbnail: NSImageView, NSDraggingSource {
    let file: URL
    init(file: URL, image: NSImage?) {
        self.file = file
        super.init(frame: .zero)
        self.image = image; imageScaling = .scaleProportionallyUpOrDown
        toolTip = L("shots_drag")
        setAccessibilityLabel(file.lastPathComponent)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { }
    override func mouseDragged(with event: NSEvent) {
        guard FileManager.default.fileExists(atPath: file.path) else { NSSound.beep(); return }
        let item = NSDraggingItem(pasteboardWriter: file as NSURL)
        item.setDraggingFrame(bounds, contents: image ?? NSWorkspace.shared.icon(forFile: file.path))
        beginDraggingSession(with: [item], event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}

final class ScreenshotShelf: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var rows = NSStackView()
    private var status = NSTextField(labelWithString: "")
    private var folderLabel = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var lastFiles: [ScreenshotFile]?
    private var generation = 0
    private var loading = false
    private var scopedURL: URL?
    private var busy = false
    private let queue = DispatchQueue(label: "local.windowmochi.screenshots", qos: .userInitiated)
    private var folder: URL? {
        guard let path = UserDefaults.standard.string(forKey: "screenshotFolder") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    override init() {
        super.init()
        if let bookmark = UserDefaults.standard.data(forKey: "screenshotFolderBookmark") {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
                if url.startAccessingSecurityScopedResource() { scopedURL = url }
                UserDefaults.standard.set(url.path, forKey: "screenshotFolder")
                if stale, let renewed = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    UserDefaults.standard.set(renewed, forKey: "screenshotFolderBookmark")
                }
            }
        }
    }
    deinit { scopedURL?.stopAccessingSecurityScopedResource(); timer?.invalidate() }
    func show() {
        if panel == nil { buildPanel() }
        panel?.title = L("shots_title")
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refresh(force: true)
        if timer == nil { timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() } }
    }
    func languageChanged() {
        guard panel != nil else { return }
        let visible = panel?.isVisible == true
        generation += 1; lastFiles = nil
        panel?.close(); panel = nil
        if visible { show() }
    }
    func windowWillClose(_ notification: Notification) { timer?.invalidate(); timer = nil }
    private func button(_ title: String, _ action: Selector) -> NSButton {
        NSButton(title: title, target: self, action: action)
    }
    private func buildPanel() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 680, height: 620), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.minSize = NSSize(width: 620, height: 360)
        panel.isReleasedWhenClosed = false; panel.delegate = self
        panel.center()
        let root = NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 16), root.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -16), root.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 16), root.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor, constant: -16)])
        let top = NSStackView(views: [button(L("shots_setup"), #selector(setup)), button(L("shots_choose"), #selector(chooseFolder))]); top.spacing = 8
        root.addArrangedSubview(top)
        let location = NSStackView(views: [button(L("shots_save_location"), #selector(saveLocation)), button(L("shots_open_folder"), #selector(openFolder))]); location.spacing = 8
        root.addArrangedSubview(location)
        folderLabel = NSTextField(labelWithString: ""); folderLabel.lineBreakMode = .byTruncatingMiddle; folderLabel.maximumNumberOfLines = 1
        root.addArrangedSubview(folderLabel)
        let help = NSTextField(wrappingLabelWithString: L("shots_hint")); help.textColor = .secondaryLabelColor; root.addArrangedSubview(help)
        let tools = NSStackView(views: [button(L("shots_import"), #selector(importDesktop)), button(L("shots_refresh"), #selector(reload))]); tools.spacing = 8; root.addArrangedSubview(tools)
        status = NSTextField(wrappingLabelWithString: ""); status.textColor = .secondaryLabelColor; root.addArrangedSubview(status)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        rows = NSStackView(); rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 10; rows.translatesAutoresizingMaskIntoConstraints = false
        let document = ShelfDocument(); document.translatesAutoresizingMaskIntoConstraints = false; document.addSubview(rows); scroll.documentView = document
        root.addArrangedSubview(scroll)
        NSLayoutConstraint.activate([scroll.widthAnchor.constraint(equalTo: root.widthAnchor), scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120), document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor), rows.leadingAnchor.constraint(equalTo: document.leadingAnchor), rows.trailingAnchor.constraint(equalTo: document.trailingAnchor), rows.topAnchor.constraint(equalTo: document.topAnchor), rows.bottomAnchor.constraint(equalTo: document.bottomAnchor)])
        for view in [folderLabel, help, status] { view.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true }
        self.panel = panel
    }
    private func alert(_ title: String, _ detail: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail; alert.addButton(withTitle: L("ok")); alert.runModal()
    }
    private func select(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        guard FileManager.default.isReadableFile(atPath: url.path), FileManager.default.isWritableFile(atPath: url.path) else { throw CocoaError(.fileReadNoPermission) }
        let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        scopedURL?.stopAccessingSecurityScopedResource(); scopedURL = nil
        if url.startAccessingSecurityScopedResource() { scopedURL = url }
        UserDefaults.standard.set(url.path, forKey: "screenshotFolder")
        UserDefaults.standard.set(bookmark, forKey: "screenshotFolderBookmark")
        generation += 1; lastFiles = nil; refresh(force: true)
    }
    @objc private func setup() {
        do { try select(ScreenshotLibrary.suggestedFolder); saveLocation() }
        catch { alert(L("shots_error"), error.localizedDescription) }
    }
    @objc private func chooseFolder() {
        let picker = NSOpenPanel(); picker.canChooseFiles = false; picker.canChooseDirectories = true; picker.allowsMultipleSelection = false; picker.canCreateDirectories = true
        picker.message = L("shots_choose_hint"); picker.directoryURL = folder ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do { try select(url) } catch { alert(L("shots_error"), error.localizedDescription) }
    }
    @objc private func saveLocation() {
        guard let folder = folder else { alert(L("shots_title"), L("shots_not_setup")); return }
        let alert = NSAlert(); alert.messageText = L("shots_save_location"); alert.informativeText = L("shots_location_help", folder.path)
        alert.addButton(withTitle: L("shots_copy_path")); alert.addButton(withTitle: L("cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(folder.path, forType: .string)
            // Launch Screenshot's public launcher, not its CoreServices UI helper.
            let app = URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
                if let error = error {
                    DispatchQueue.main.async { self?.alert(L("shots_error"), L("shots_launch_help", error.localizedDescription)) }
                }
            }
        }
    }
    @objc private func openFolder() {
        guard let folder = folder else { alert(L("shots_title"), L("shots_not_setup")); return }
        NSWorkspace.shared.open(folder)
    }
    @objc private func reload() { refresh(force: true) }
    private func refresh(force: Bool = false) {
        folderLabel.stringValue = folder?.path ?? L("shots_not_setup")
        folderLabel.toolTip = folder?.path
        guard panel?.isVisible == true, !busy, !loading, let folder = folder else {
            if self.folder == nil { status.stringValue = L("shots_not_setup") }
            return
        }
        loading = true
        let token = generation
        let previous = force ? nil : lastFiles
        queue.async { [weak self] in
            do {
                let files = try ScreenshotLibrary.images(in: folder)
                let thumbnails: [URL: NSImage] = files == previous ? [:] : Dictionary(uniqueKeysWithValues: files.compactMap { file in
                    guard let source = CGImageSourceCreateWithURL(file.url as CFURL, nil),
                          let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 280, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
                    return (file.url, NSImage(cgImage: cg, size: .zero))
                })
                DispatchQueue.main.async {
                    guard let self = self else { return }; self.loading = false
                    guard self.generation == token else { self.refresh(force: true); return }
                    self.status.stringValue = files.isEmpty ? L("shots_empty") : L("shots_count", files.count)
                    if self.lastFiles != files || force { self.lastFiles = files; self.render(files, thumbnails: thumbnails) }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self = self else { return }; self.loading = false
                    guard self.generation == token else { self.refresh(force: true); return }
                    self.status.stringValue = L("shots_read_error", error.localizedDescription)
                    self.lastFiles = nil; self.render([], thumbnails: [:])
                }
            }
        }
    }
    private func render(_ files: [ScreenshotFile], thumbnails: [URL: NSImage]) {
        for view in rows.arrangedSubviews { rows.removeArrangedSubview(view); view.removeFromSuperview() }
        let formatter = DateFormatter(); formatter.dateStyle = .short; formatter.timeStyle = .short
        for file in files {
            let preview = ShelfThumbnail(file: file.url, image: thumbnails[file.url] ?? NSWorkspace.shared.icon(forFile: file.url.path))
            preview.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([preview.widthAnchor.constraint(equalToConstant: 140), preview.heightAnchor.constraint(equalToConstant: 90)])
            let title = NSTextField(labelWithString: file.url.lastPathComponent); title.lineBreakMode = .byTruncatingMiddle; title.toolTip = file.url.lastPathComponent
            let date = NSTextField(labelWithString: formatter.string(from: file.date)); date.textColor = .secondaryLabelColor
            let actions = NSStackView()
            for (key, selector) in [("shots_preview", #selector(previewFile(_:))), ("shots_copy", #selector(copyFile(_:))), ("shots_reveal", #selector(revealFile(_:)))] {
                let action = NSButton(title: L(key), target: self, action: selector); action.identifier = NSUserInterfaceItemIdentifier(file.url.path); actions.addArrangedSubview(action)
            }
            let details = NSStackView(views: [title, date, actions]); details.orientation = .vertical; details.alignment = .leading; details.spacing = 6
            let row = NSStackView(views: [preview, details]); row.spacing = 14; row.alignment = .centerY
            rows.addArrangedSubview(row); row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
            title.widthAnchor.constraint(lessThanOrEqualTo: details.widthAnchor).isActive = true
        }
    }
    private func file(_ sender: NSButton) -> URL? { sender.identifier.map { URL(fileURLWithPath: $0.rawValue) } }
    @objc private func previewFile(_ sender: NSButton) { if let file = file(sender) { NSWorkspace.shared.open(file) } }
    @objc private func revealFile(_ sender: NSButton) { if let file = file(sender) { NSWorkspace.shared.activateFileViewerSelecting([file]) } }
    @objc private func copyFile(_ sender: NSButton) {
        guard let url = file(sender), let image = NSImage(contentsOf: url) else { alert(L("shots_error"), L("shots_missing")); return }
        NSPasteboard.general.clearContents()
        if !NSPasteboard.general.writeObjects([image]) { alert(L("shots_error"), L("shots_copy_error")) }
    }
    @objc private func importDesktop() {
        guard !busy else { return }
        guard let destination = folder else { alert(L("shots_title"), L("shots_not_setup")); return }
        let picker = NSOpenPanel(); picker.canChooseFiles = false; picker.canChooseDirectories = true; picker.allowsMultipleSelection = false
        picker.message = L("shots_desktop_hint"); picker.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        guard picker.runModal() == .OK, let desktop = picker.url else { return }
        let access = desktop.startAccessingSecurityScopedResource(); defer { if access { desktop.stopAccessingSecurityScopedResource() } }
        do {
            let candidates = try ScreenshotLibrary.desktopCandidates(in: desktop)
            guard !candidates.isEmpty else { alert(L("shots_title"), L("shots_no_candidates")); return }
            let checks = candidates.map { file -> NSButton in
                let button = NSButton(checkboxWithTitle: file.url.lastPathComponent, target: nil, action: nil); button.state = .off; button.toolTip = file.url.path; return button
            }
            let list = NSStackView(views: checks); list.orientation = .vertical; list.alignment = .leading; list.spacing = 6
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 240)); scroll.hasVerticalScroller = true
            let document = ShelfDocument(frame: NSRect(x: 0, y: 0, width: 460, height: max(240, checks.count * 26)))
            list.frame = document.bounds; list.autoresizingMask = [.width]; document.addSubview(list); scroll.documentView = document
            let selection = ScreenshotSelection(checks)
            let bulk = NSStackView(views: [
                NSButton(title: L("shots_select_all"), target: selection, action: #selector(ScreenshotSelection.selectAll)),
                NSButton(title: L("shots_deselect_all"), target: selection, action: #selector(ScreenshotSelection.deselectAll))
            ])
            bulk.spacing = 8
            let accessory = NSStackView(views: [bulk, scroll])
            accessory.orientation = .vertical; accessory.alignment = .leading; accessory.spacing = 10
            accessory.frame = NSRect(x: 0, y: 0, width: 480, height: 280)
            NSLayoutConstraint.activate([scroll.widthAnchor.constraint(equalToConstant: 480), scroll.heightAnchor.constraint(equalToConstant: 240)])
            let confirm = NSAlert(); confirm.messageText = L("shots_import"); confirm.informativeText = L("shots_import_help", destination.path); confirm.accessoryView = accessory
            confirm.addButton(withTitle: L("cancel")); confirm.addButton(withTitle: L("shots_move"))
            let response = withExtendedLifetime(selection) { confirm.runModal() }
            guard response == .alertSecondButtonReturn else { return }
            let selected = zip(candidates, checks).filter { $0.1.state == .on }.map { $0.0 }
            guard !selected.isEmpty else { return }
            busy = true
            status.stringValue = L("shots_moving")
            // Hold both folder grants until the asynchronous transfer completes.
            let sourceAccess = desktop.startAccessingSecurityScopedResource()
            let destinationAccess = destination.startAccessingSecurityScopedResource()
            queue.async { [weak self] in
                defer {
                    if sourceAccess { desktop.stopAccessingSecurityScopedResource() }
                    if destinationAccess { destination.stopAccessingSecurityScopedResource() }
                }
                var moved = 0, errors: [String] = []
                for file in selected {
                    do { _ = try ScreenshotLibrary.moveScreenshot(file.url, to: destination); moved += 1 }
                    catch { errors.append("\(file.url.lastPathComponent): \(error.localizedDescription)") }
                }
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.busy = false; self.refresh(force: true)
                    self.alert(L("shots_title"), L("shots_moved", moved, errors.count) + (errors.isEmpty ? "" : "\n\n" + errors.joined(separator: "\n")))
                }
            }
        } catch { busy = false; alert(L("shots_error"), error.localizedDescription) }
    }
}
