"""Run the real restore action with deterministic display/window/AX fixtures."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/WindowMochi/main.swift').read_text()
models = source[source.index('struct Placement:'):source.index('struct Display')]
method = source[source.index('    func restoreLayout('):source.index('    func cycle(')]
method = method.replace('NSScreen.screens', 'TestScreen.screens').replace('AXUIElementSetAttributeValue(', 'fakeSet(')
fixture = r'''
import Cocoa
import ApplicationServices
''' + models + r'''
struct Display {
    var id: UInt32; var bounds: CGRect; var key: String; var builtIn: Bool
    var restoreScreen: RestoreScreen { RestoreScreen(key: key, builtIn: builtIn, bounds: bounds, visible: bounds) }
}
struct Window { var element: Int; var bundle: String; var title: String; var index: Int; var rect: CGRect; var identifier: String? = nil }
struct TestScreen {
    static var screens: [TestScreen] = []
    var deviceDescription: [NSDeviceDescriptionKey: Any] = [:]
    var frame = CGRect.zero
    var visibleFrame = CGRect.zero
}
var currentScreens: [Display] = []
var currentWindows: [Window] = []
var positions: [Int: CGPoint] = [:]
var sizes: [Int: CGSize] = [:]
var refuseResize = false
func readWindowRect(_ element: Int) -> CGRect? {
    guard let window = currentWindows.first(where: { $0.element == element }) else { return nil }
    return CGRect(origin: positions[element] ?? window.rect.origin, size: sizes[element] ?? window.rect.size)
}
func displays() -> [Display] { currentScreens }
func windows() -> [Window] { currentWindows }
func L(_ key: String, _ args: CVarArg...) -> String { key + "|" + args.map { String(describing: $0) }.joined(separator: "|") }
func fakeSet(_ element: Int, _ key: CFString, _ value: AXValue) -> AXError {
    if key as String == kAXPositionAttribute {
        var point = CGPoint.zero; _ = AXValueGetValue(value, .cgPoint, &point); positions[element] = point
    }
    if key as String == kAXSizeAttribute && !refuseResize {
        var size = CGSize.zero; _ = AXValueGetValue(value, .cgSize, &size); sizes[element] = size
    }
    return .success
}
final class Harness {
    var layouts: [Layout] = []
    var activeIndex: Int?
    var isRestoring = false
    var lastMessage = ""
    func trusted() -> Bool { true }
    func rebuild() {}
    func message(_ title: String, _ detail: String) { lastMessage = detail }
''' + method + r'''
}
let internalDisplay = Display(id: 1, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900), key: "internal", builtIn: true)
let externalDisplay = Display(id: 2, bounds: CGRect(x: 1440, y: 0, width: 2560, height: 1440), key: "external-reconnected", builtIn: false)
func placement(_ title: String, _ index: Int, _ display: String, _ builtIn: Bool, _ x: Double) -> Placement {
    Placement(bundle: "test.app", title: title, index: index, display: display, builtIn: builtIn, x: x, y: 0.1, width: 0.3, height: 0.4)
}
func window(_ element: Int, _ title: String, _ index: Int) -> Window {
    Window(element: element, bundle: "test.app", title: title, index: index, rect: CGRect(x: 10, y: 10, width: 400, height: 300))
}
var failures: [String] = []
let app = Harness()
func wait() {
    let deadline = Date().addingTimeInterval(3)
    while app.isRestoring && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    if app.isRestoring { print("FAIL: restore did not finish"); exit(1) }
}
currentScreens = [internalDisplay, externalDisplay]
currentWindows = [window(1, "Editor", 0)]
app.layouts = [Layout(name: "Home", windows: [placement("Editor", 0, "external-before-reconnect", false, 0.25)])]
app.restoreLayout(0); wait()
if positions[1]?.x != 2080 { failures.append("reconnected external display: expected x=2080 on external display; got \(positions[1]?.x ?? -1)") }
positions = [:]; sizes = [:]
currentScreens = [internalDisplay]
currentWindows = [window(1, "Mail", 0), window(2, "New tab title", 1)]
app.layouts = [Layout(name: "Work", windows: [placement("Old tab title", 0, "internal", true, 0), placement("Mail", 1, "internal", true, 0.5)])]
app.restoreLayout(0); wait()
if positions[1]?.x != 720 || positions[2]?.x != 0 { failures.append("window matching: a changed title stole a later exact-title match") }
positions = [:]; sizes = [:]; refuseResize = true
currentWindows = [window(1, "Editor", 0)]
app.layouts = [Layout(name: "Minimum size", windows: [placement("Editor", 0, "internal", true, 0.25)])]
app.restoreLayout(0); wait()
if !app.lastMessage.contains("report|0|0|1") { failures.append("AX success without actual resize must be reported as unverified failure") }
for failure in failures { print("FAIL: " + failure) }
if !failures.isEmpty { exit(1) }
print("PASS: actual restore action handles external reconnection and protects exact window matches, and verifies actual geometry")
'''
build = root / '.build/restore-test'
build.mkdir(parents=True, exist_ok=True)
path = build / 'main.swift'; path.write_text(fixture)
flags = []
if (root / '.build/overlay.json').exists():
    flags = ['-vfsoverlay', str(root / '.build/overlay.json')]
subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', str(root / '.build/module-cache2'), *flags, str(root / 'Sources/WindowMochi/LayoutRestore.swift'), str(path), '-o', str(build/'restore-test')], check=True)
subprocess.run([str(build/'restore-test')], check=True)
