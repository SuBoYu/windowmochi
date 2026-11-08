import Cocoa
import ApplicationServices

struct Placement: Codable {
    var bundle: String
    var title: String
    var index: Int
    var display: String
    var builtIn: Bool
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    // Optional fields preserve decoding of existing snapshots.
    var windowIdentifier: String? = nil
    var displayName: String? = nil
    var displayVendor: UInt32? = nil
    var displayModel: UInt32? = nil
    var displaySerial: UInt32? = nil
    var coordinateSpace: String? = nil
}
struct Layout: Codable {
    var name: String
    var windows: [Placement]
}
struct Display {
    var id: CGDirectDisplayID
    var bounds: CGRect
    var key: String { CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? String(id) }
    var builtIn: Bool { CGDisplayIsBuiltin(id) != 0 }
    var restoreScreen: RestoreScreen {
        let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }
        let visible = screen.map { LayoutRestore.visibleFrame(appKitFrame: $0.frame, appKitVisible: $0.visibleFrame, quartzBounds: bounds) } ?? bounds
        return RestoreScreen(key: key, builtIn: builtIn, bounds: bounds, visible: visible, name: screen?.localizedName ?? "", vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id), serial: CGDisplaySerialNumber(id))
    }
}
struct Window {
    var element: AXUIElement
    var bundle: String
    var title: String
    var index: Int
    var rect: CGRect
    var identifier: String? = nil
}
func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
    return result
}
func readWindowRect(_ element: AXUIElement) -> CGRect? {
    guard let p = attribute(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
          let s = attribute(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero, size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: point, size: size)
}
func displays() -> [Display] {
    NSScreen.screens.compactMap { screen in
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return Display(id: id.uint32Value, bounds: CGDisplayBounds(id.uint32Value))
    }
}
func windows() -> [Window] {
    var result: [Window] = []
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
        guard let bundle = app.bundleIdentifier else { continue }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.5)
        guard let elements = attribute(root, kAXWindowsAttribute) as? [AXUIElement] else { continue }
        for (index, element) in elements.enumerated() {
            guard attribute(element, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole,
                  (attribute(element, kAXMinimizedAttribute) as? Bool) != true,
                  (attribute(element, "AXFullScreen") as? Bool) != true,
                  let p = attribute(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
                  let s = attribute(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { continue }
            var point = CGPoint.zero
            var size = CGSize.zero
            guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size), size.width > 0, size.height > 0 else { continue }
            result.append(Window(element: element, bundle: bundle, title: attribute(element, kAXTitleAttribute) as? String ?? "", index: index, rect: CGRect(origin: point, size: size), identifier: attribute(element, "AXIdentifier") as? String))
        }
    }
    return result
}

final class App: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    var layouts: [Layout] = []
    var hotkeys: Hotkeys?
    var activeIndex: Int?
    var isRestoring = false
    private lazy var screenshots = ScreenshotShelf()
    let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WindowHabit/layouts.json")
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let data = try? Data(contentsOf: file) {
            do { layouts = try JSONDecoder().decode([Layout].self, from: data) }
            catch { message(L("load_error"), L("load_detail", file.path)) }
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menuIcon = NSApp.applicationIconImage.copy() as? NSImage
        menuIcon?.size = NSSize(width: 22, height: 22)
        item.button?.image = menuIcon
        item.button?.setAccessibilityLabel("WindowMochi")
        item.button?.toolTip = "WindowMochi"
        rebuild()
        hotkeys = Hotkeys { [weak self] id in
            guard let self = self else { return }
            if id == 12 { self.screenshots.show() }
            else if id <= 9 { self.restoreLayout(Int(id) - 1, quiet: true) }
            else { self.cycle(id == 10 ? 1 : -1) }
        }
        let conflicts = hotkeys?.register() ?? []
        if !conflicts.isEmpty { message(L("hotkey_error"), L("hotkey_detail", conflicts.joined(separator: ", "))) }
        if CommandLine.arguments.contains("--show-screenshots") { screenshots.show() }
    }
    func rebuild() {
        let menu = NSMenu()
        add(L("about"), #selector(about), to: menu)
        menu.addItem(.separator())
        add(L("shots_menu"), #selector(showScreenshots), to: menu)
        menu.addItem(.separator())
        add(L("save_current"), #selector(snapshot), to: menu)
        menu.addItem(.separator())
        if layouts.isEmpty { let row = NSMenuItem(title: L("empty"), action: nil, keyEquivalent: ""); row.isEnabled = false; menu.addItem(row) }
        for (index, layout) in layouts.enumerated() {
            let row = NSMenuItem(title: L("restore_row", layout.name, layout.windows.count), action: #selector(restore(_:)), keyEquivalent: "")
            row.target = self; row.tag = index
            if index < 9 { row.title += "  ⌃⌥⌘" + String(index + 1) }
            row.state = activeIndex == index ? .on : .off
            menu.addItem(row)
        }
        menu.addItem(.separator())
        if !layouts.isEmpty {
            let deletions = NSMenu()
            for (index, layout) in layouts.enumerated() {
                let row = NSMenuItem(title: layout.name, action: #selector(confirmDeleteLayout(_:)), keyEquivalent: "")
                row.target = self; row.tag = index; deletions.addItem(row)
            }
            let deleteMenu = NSMenuItem(title: L("delete_layout_menu"), action: nil, keyEquivalent: "")
            deleteMenu.submenu = deletions; menu.addItem(deleteMenu)
            menu.addItem(.separator())
        }
        add(L("previous") + "  ⌃⌥⌘←", #selector(previousLayout), to: menu)
        add(L("next") + "  ⌃⌥⌘→", #selector(nextLayout), to: menu)
        let languages = NSMenu()
        for (code, title) in [("system", L("system")), ("en", "English"), ("zh-Hant", "繁體中文"), ("zh-Hans", "简体中文"), ("ja", "日本語")] {
            let row = NSMenuItem(title: title, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            row.target = self; row.representedObject = code
            row.state = Localizer.shared.selection == code ? .on : .off
            languages.addItem(row)
        }
        let language = NSMenuItem(title: L("language"), action: nil, keyEquivalent: "")
        language.submenu = languages; menu.addItem(language)
        add(L("folder"), #selector(openFolder), to: menu)
        add(L("permission"), #selector(permission), to: menu)
        add(L("quit"), #selector(quit), to: menu)
        item.menu = menu
    }
    func add(_ title: String, _ action: Selector, to menu: NSMenu) {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: ""); row.target = self; menu.addItem(row)
    }
    func message(_ title: String, _ detail: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail; alert.addButton(withTitle: L("ok")); alert.runModal()
    }
    func trusted() -> Bool {
        guard AXIsProcessTrusted() else { permission(); return false }
        return true
    }
    @objc func permission() {
        if AXIsProcessTrusted() {
            message(L("permission_enabled_title"), L("permission_enabled_detail"))
            return
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            message(L("permission_enabled_title"), L("permission_enabled_detail"))
        } else {
            // The system prompt is asynchronous: do not claim that the user has not enabled the switch.
            message(L("allow"), L("permission_detail", Bundle.main.bundlePath))
        }
    }
    @objc func snapshot() {
        guard !isRestoring else { NSSound.beep(); return }
        guard trusted() else { return }
        let screens = displays()
        let saved = windows().compactMap { window -> Placement? in
            guard let screen = screens.max(by: { $0.bounds.intersection(window.rect).area < $1.bounds.intersection(window.rect).area }) else { return nil }
            let info = screen.restoreScreen
            let r = window.rect, b = info.visible
            return Placement(bundle: window.bundle, title: window.title, index: window.index, display: screen.key, builtIn: screen.builtIn, x: (r.minX-b.minX)/b.width, y: (r.minY-b.minY)/b.height, width: r.width/b.width, height: r.height/b.height, windowIdentifier: window.identifier, displayName: info.name, displayVendor: info.vendor, displayModel: info.model, displaySerial: info.serial, coordinateSpace: "visible-v1")
        }
        guard !saved.isEmpty else { message(L("no_windows"), L("no_windows_detail")); return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = L("save_count", saved.count); alert.informativeText = L("name_hint")
        let field = NSTextField(string: L("work")); field.frame = NSRect(x: 0, y: 0, width: 280, height: 24); alert.accessoryView = field
        alert.addButton(withTitle: L("save")); alert.addButton(withTitle: L("cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if layouts.contains(where: { $0.name == name }) {
            let confirm = NSAlert(); confirm.messageText = L("overwrite_title", name); confirm.addButton(withTitle: L("overwrite")); confirm.addButton(withTitle: L("cancel"))
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
        }
        var updated = layouts
        if let index = updated.firstIndex(where: { $0.name == name }) { updated[index] = Layout(name: name, windows: saved) }
        else { updated.append(Layout(name: name, windows: saved)) }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: file, options: .atomic)
            layouts = updated; rebuild()
        } catch { message(L("save_error"), error.localizedDescription) }
    }
    @objc func confirmDeleteLayout(_ sender: NSMenuItem) {
        guard !isRestoring else { NSSound.beep(); return }
        let index = sender.tag
        guard layouts.indices.contains(index) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("delete_layout_title", layouts[index].name)
        alert.informativeText = L("delete_layout_detail")
        // Cancel is the default so Return cannot accidentally confirm deletion.
        alert.addButton(withTitle: L("cancel"))
        alert.addButton(withTitle: L("delete_layout_button"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do { try deleteLayout(at: index) }
        catch { message(L("delete_layout_error"), error.localizedDescription) }
    }
    func deleteLayout(at index: Int) throws {
        guard layouts.indices.contains(index) else { return }
        var updated = layouts
        updated.remove(at: index)
        // Commit to disk before changing live state, so a failed write preserves the layout.
        try JSONEncoder().encode(updated).write(to: file, options: .atomic)
        layouts = updated
        if let active = activeIndex {
            if active == index { activeIndex = nil }
            else if active > index { activeIndex = active - 1 }
        }
        rebuild()
    }
    @objc func restore(_ sender: NSMenuItem) {
        restoreLayout(sender.tag)
    }
    func restoreLayout(_ layoutIndex: Int, quiet: Bool = false) {
        guard !isRestoring, layouts.indices.contains(layoutIndex), trusted() else { return }
        let screens = displays().map(\.restoreScreen)
        guard !screens.isEmpty else { return }
        let saved = layouts[layoutIndex].windows
        let available = windows()
        let mapping = LayoutRestore.mapDisplays(saved, to: screens)
        let matches = LayoutRestore.matchWindows(saved, to: available.map { RestoreWindow(bundle: $0.bundle, title: $0.title, index: $0.index, identifier: $0.identifier) })
        var targets: [RestoreTarget] = []
        for savedIndex in saved.indices {
            guard let windowIndex = matches[savedIndex], let screen = mapping.screens[saved[savedIndex].display],
                  let rect = LayoutRestore.target(saved[savedIndex], on: screen) else { continue }
            targets.append(RestoreTarget(windowIndex: windowIndex, rect: rect, visible: screen.visible))
        }
        let missing = saved.count - matches.count
        let invalid = matches.count - targets.count
        isRestoring = true
        RestoreRunner(targets: targets, apply: { target in
            let element = available[target.windowIndex].element
            var size = target.rect.size
            let value = AXValueCreate(.cgSize, &size)!
            _ = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
            // If an app enforces a minimum size, keep even that larger window on screen.
            let actual = readWindowRect(element)?.size ?? size
            var point = LayoutRestore.clampedOrigin(target.rect.origin, size: actual, visible: target.visible)
            let position = AXValueCreate(.cgPoint, &point)!
            _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, position)
            _ = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        }, read: { index in readWindowRect(available[index].element) }, completion: { [weak self] restored, failures in
            guard let self = self else { return }
            self.isRestoring = false
            if restored > 0 { self.activeIndex = layoutIndex }
            self.rebuild()
            let failed = failures + invalid
            let changedDisplays = !mapping.remapped.isEmpty || !mapping.unavailable.isEmpty
            if !quiet || missing > 0 || failed > 0 || changedDisplays {
                var detail = L("report", restored, missing, failed)
                if changedDisplays { detail += "\n\n" + L("restore_displays", mapping.remapped.count, mapping.unavailable.count) }
                self.message(L("restored"), detail)
            }
        }).start()
    }
    func cycle(_ direction: Int) {
        guard !layouts.isEmpty else { return }
        let start = activeIndex ?? (direction > 0 ? -1 : 0)
        restoreLayout((start + direction + layouts.count) % layouts.count, quiet: true)
    }
    @objc func previousLayout() { cycle(-1) }
    @objc func nextLayout() { cycle(1) }
    @objc func showScreenshots() { screenshots.show() }
    @objc func changeLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        Localizer.shared.select(code); rebuild(); screenshots.languageChanged()
    }
    @objc func openFolder() {
        do { try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true); NSWorkspace.shared.open(file.deletingLastPathComponent()) }
        catch { message(L("folder_error"), error.localizedDescription) }
    }
    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "WindowMochi"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0"
        alert.informativeText = L("about_detail", version)
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: L("ok"))
        alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
}
extension CGRect { var area: CGFloat { isNull ? 0 : width * height } }
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
