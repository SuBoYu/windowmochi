"""Exercise the screenshot library against temporary files, never the real Desktop."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
fixture = r'''
import Foundation
import Darwin
func check(_ condition: Bool, _ label: String) {
    if !condition { print("FAIL: " + label); exit(1) }
}
let manager = FileManager.default
let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try manager.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? manager.removeItem(at: root) }
let desktop = root.appendingPathComponent("Desktop")
let shelf = root.appendingPathComponent("Shelf")
try manager.createDirectory(at: desktop, withIntermediateDirectories: true)
try manager.createDirectory(at: shelf, withIntermediateDirectories: true)
func make(_ folder: URL, _ name: String, _ content: String = "image", marked: Bool = false, date: Double = 100) throws -> URL {
    let file = folder.appendingPathComponent(name)
    try Data(content.utf8).write(to: file)
    try manager.setAttributes([.modificationDate: Date(timeIntervalSince1970: date)], ofItemAtPath: file.path)
    if marked {
        let flag = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
        let result = flag.withUnsafeBytes { setxattr(file.path, "com.apple.metadata:kMDItemIsScreenCapture", $0.baseAddress, flag.count, 0, 0) }
        check(result == 0, "fixture screenshot metadata")
    }
    return file
}
let ordinary = try make(desktop, "photo.png")
let namedOnly = try make(desktop, "Screenshot 2026-10-28.png")
let capture = try make(desktop, "capture.png", "new", marked: true)
let second = try make(desktop, "capture2.PNG", "second", marked: true)
_ = try make(desktop, "note.txt", marked: true)
_ = try make(desktop, ".hidden.png", marked: true)
_ = try make(desktop, "empty.png", "", marked: true)
try manager.createDirectory(at: desktop.appendingPathComponent("directory.png"), withIntermediateDirectories: true)
try manager.createSymbolicLink(at: desktop.appendingPathComponent("linked.png"), withDestinationURL: capture)
let candidates = try ScreenshotLibrary.desktopCandidates(in: desktop)
check(Set(candidates.map { $0.url.lastPathComponent }) == ["capture.png", "capture2.PNG"], "only real marked image files are cleanup candidates")
_ = try make(shelf, "capture.png", "existing")
let moved = try ScreenshotLibrary.moveScreenshot(capture, to: shelf)
check(moved.lastPathComponent == "capture (2).png", "duplicate names keep both files")
let oldData = try Data(contentsOf: shelf.appendingPathComponent("capture.png"))
let newData = try Data(contentsOf: moved)
check(String(data: oldData, encoding: .utf8) == "existing" && String(data: newData, encoding: .utf8) == "new", "never overwrite destination data")
check(!manager.fileExists(atPath: capture.path), "successful move removes only the selected source")
check(manager.fileExists(atPath: second.path) && manager.fileExists(atPath: ordinary.path) && manager.fileExists(atPath: namedOnly.path), "unchecked and unmarked files stay in place")
var rejected = false
do { _ = try ScreenshotLibrary.moveScreenshot(ordinary, to: shelf) } catch { rejected = true }
check(rejected && manager.fileExists(atPath: ordinary.path), "unmarked files cannot be moved by cleanup")
rejected = false
do { _ = try ScreenshotLibrary.moveScreenshot(second, to: desktop) } catch { rejected = true }
check(rejected, "source folder cannot also be the destination")
rejected = false
do { _ = try ScreenshotLibrary.moveScreenshot(second, to: root.appendingPathComponent("missing")) } catch { rejected = true }
check(rejected && manager.fileExists(atPath: second.path), "failed move preserves source")
for i in 0..<35 { _ = try make(shelf, "shot-\(i).png", date: Double(1000+i)) }
let recent = try ScreenshotLibrary.images(in: shelf)
check(recent.count == 30 && recent.first?.url.lastPathComponent == "shot-34.png" && recent.last?.url.lastPathComponent == "shot-5.png", "newest-first list is limited to 30")
try manager.removeItem(at: recent[0].url)
let refreshed = try ScreenshotLibrary.images(in: shelf)
check(refreshed[0].url.lastPathComponent == "shot-33.png", "refresh drops missing files")
let empty = try ScreenshotLibrary.images(in: shelf, limit: 0)
check(empty.isEmpty, "zero limit is empty")
rejected = false
do { _ = try ScreenshotLibrary.images(in: root.appendingPathComponent("gone")) } catch { rejected = true }
check(rejected, "missing folder is reported rather than silently empty")
print("PASS: screenshot metadata filtering, newest-30 ordering, safe moves, collisions, missing files, and source preservation")
'''
build = root / '.build/screenshot-test'
build.mkdir(parents=True, exist_ok=True)
source = build / 'main.swift'
source.write_text(fixture)
flags = []
if (root / '.build/overlay.json').exists():
    flags = ['-vfsoverlay', str(root / '.build/overlay.json')]
subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', str(root / '.build/module-cache2'), *flags, str(root / 'Sources/WindowMochi/ScreenshotLibrary.swift'), str(source), '-o', str(build / 'screenshot-test')], check=True)
subprocess.run([str(build / 'screenshot-test')], check=True)
