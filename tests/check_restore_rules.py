"""Exercise production restore rules, legacy JSON, and delayed AX verification."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/WindowMochi/main.swift').read_text()
models = source[source.index('struct Placement:'):source.index('struct Display')]
fixture = r'''
import Foundation
import CoreGraphics
''' + models + r'''
func check(_ value: Bool, _ message: String) { if !value { print("FAIL: " + message); exit(1) } }
func placement(_ display: String, _ builtIn: Bool = false) -> Placement {
    Placement(bundle: "test", title: "Window", index: 0, display: display, builtIn: builtIn, x: 0.25, y: 0.25, width: 0.5, height: 0.5)
}
let internalScreen = RestoreScreen(key: "internal", builtIn: true, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900), visible: CGRect(x: 0, y: 25, width: 1440, height: 825))
let external = RestoreScreen(key: "external-new", builtIn: false, bounds: CGRect(x: -2560, y: -200, width: 2560, height: 1440), visible: CGRect(x: -2560, y: -172, width: 2560, height: 1362), name: "Monitor", vendor: 10, model: 20, serial: 30)
var saved = placement("external-old")
var mapping = LayoutRestore.mapDisplays([saved], to: [internalScreen, external])
check(mapping.screens[saved.display]?.key == external.key && mapping.remapped.count == 1, "legacy external role stays on the external display")
mapping = LayoutRestore.mapDisplays([saved], to: [internalScreen])
check(mapping.screens[saved.display]?.key == internalScreen.key && mapping.unavailable.count == 1, "truly absent external display falls back explicitly")
var other = external; other.key = "other"; other.serial = 99
mapping = LayoutRestore.mapDisplays([saved], to: [internalScreen, external, other])
check(mapping.unavailable.count == 1, "ambiguous external displays are not guessed")
saved.displayVendor = 10; saved.displayModel = 20; saved.displaySerial = 30; saved.displayName = "Monitor"
mapping = LayoutRestore.mapDisplays([saved], to: [other, internalScreen, external])
check(mapping.screens[saved.display]?.key == external.key, "hardware serial identifies the monitor regardless of array order")
var exact = placement("other")
mapping = LayoutRestore.mapDisplays([saved, exact], to: [internalScreen, external, other])
check(mapping.screens["other"]?.key == "other" && mapping.screens[saved.display]?.key == external.key, "fallback cannot steal another saved physical display")
var first = placement("old-a"), second = placement("old-b")
mapping = LayoutRestore.mapDisplays([first, second], to: [internalScreen, external])
check(mapping.unavailable.count == 2, "two missing external roles do not collapse onto a single external monitor")
let converted = LayoutRestore.visibleFrame(appKitFrame: CGRect(x: -2560, y: 200, width: 2560, height: 1440), appKitVisible: CGRect(x: -2500, y: 200, width: 2500, height: 1412), quartzBounds: CGRect(x: -2560, y: -500, width: 2560, height: 1440))
check(converted == CGRect(x: -2500, y: -472, width: 2500, height: 1412), "screen-local conversion handles negative origins, menu bar, and side Dock")
let legacyJSON = Data(#"[{"name":"Legacy","windows":[{"bundle":"test","title":"Window","index":0,"display":"internal","builtIn":true,"x":0.25,"y":0.25,"width":0.5,"height":0.5}]}]"#.utf8)
let legacy = try JSONDecoder().decode([Layout].self, from: legacyJSON)
check(legacy[0].windows[0].coordinateSpace == nil, "existing snapshots decode without migration or data loss")
let oldRect = LayoutRestore.target(legacy[0].windows[0], on: internalScreen)
check(oldRect == CGRect(x: 360, y: 225, width: 720, height: 450), "legacy coordinates retain full-display semantics")
var modern = legacy[0].windows[0]; modern.coordinateSpace = "visible-v1"
let modernRect = LayoutRestore.target(modern, on: internalScreen)
check(modernRect == CGRect(x: 360, y: 231.25, width: 720, height: 412.5), "new snapshots scale within usable space")
modern.x = 2; modern.y = -2; modern.width = 2; modern.height = 2
check(LayoutRestore.target(modern, on: internalScreen) == internalScreen.visible, "offscreen and oversized windows are contained")
modern.x = .nan
check(LayoutRestore.target(modern, on: internalScreen) == nil, "invalid coordinates cannot be sent to AX")
var one = placement("internal", true); one.title = ""; one.index = 0
var two = one; two.index = 1
let unknownWindows = [RestoreWindow(bundle: "test", title: "", index: 3), RestoreWindow(bundle: "test", title: "", index: 4)]
check(LayoutRestore.matchWindows([one, two], to: unknownWindows).isEmpty, "multiple anonymous windows are not assigned arbitrarily")
one.windowIdentifier = "stable-1"
let identified = [RestoreWindow(bundle: "test", title: "changed", index: 7, identifier: "stable-1")]
check(LayoutRestore.matchWindows([one], to: identified)[0] == 0, "AX identifier survives title and index changes")
var duplicateA = one, duplicateB = one
 duplicateA.title = "Old title"; duplicateB.title = "Mail"; duplicateB.index = 1
let reusedIdentifier = [RestoreWindow(bundle: "test", title: "Mail", index: 1, identifier: "stable-1")]
let duplicateMatches = LayoutRestore.matchWindows([duplicateA, duplicateB], to: reusedIdentifier)
check(duplicateMatches[1] == 0 && duplicateMatches[0] == nil, "reused AX identifiers cannot steal an exact title match")
let target = RestoreTarget(windowIndex: 0, rect: CGRect(x: 100, y: 100, width: 700, height: 500), visible: internalScreen.visible)
var queued: [() -> Void] = [], applied = 0, finished: (Int, Int)?
var rect = CGRect.zero
let runner = RestoreRunner(targets: [target], apply: { _ in applied += 1; if applied == 2 { rect = target.rect } }, read: { _ in rect }, schedule: { _, work in queued.append(work) }, completion: { finished = ($0, $1) })
runner.start()
check(finished == nil && applied == 1, "AX requests are not counted as immediate success")
while !queued.isEmpty { queued.removeFirst()() }
check(applied == 2 && finished?.0 == 1 && finished?.1 == 0, "delayed app geometry is retried then verified")
queued = []; applied = 0; finished = nil
let refusing = RestoreRunner(targets: [target], apply: { _ in applied += 1 }, read: { _ in CGRect.zero }, schedule: { _, work in queued.append(work) }, completion: { finished = ($0, $1) })
refusing.start(); while !queued.isEmpty { queued.removeFirst()() }
check(applied == 3 && finished?.0 == 0 && finished?.1 == 1, "minimum-size or refused moves fail honestly after bounded retries")
print("PASS: display mapping, coordinate conversion, legacy snapshots, stable window matching, and verified retries")
'''
build = root / '.build/restore-rules-test'; build.mkdir(parents=True, exist_ok=True)
path = build / 'main.swift'; path.write_text(fixture)
flags = []
if (root / '.build/overlay.json').exists(): flags = ['-vfsoverlay', str(root / '.build/overlay.json')]
subprocess.run(['xcrun','swiftc','-swift-version','5','-module-cache-path',str(root / '.build/module-cache2'),*flags,str(root / 'Sources/WindowMochi/LayoutRestore.swift'),str(path),'-o',str(build/'test')],check=True)
subprocess.run([str(build/'test')],check=True)
