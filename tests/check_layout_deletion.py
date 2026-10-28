"""Exercise the actual deletion method against isolated temporary files."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/WindowMochi/main.swift').read_text()
models = source[source.index('struct Placement:'):source.index('struct Display')]
method = source[source.index('    func deleteLayout(at index:'):source.index('    @objc func restore(')]
fixture = '''import Foundation
''' + models + '''
final class Harness {
    var layouts: [Layout] = []
    var activeIndex: Int?
    var file: URL
    var rebuilds = 0
    init(_ file: URL) { self.file = file }
    func rebuild() { rebuilds += 1 }
''' + method + '''
}
func check(_ condition: Bool, _ label: String) {
    if !condition { print("FAIL: " + label); exit(1) }
}
let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let file = folder.appendingPathComponent("layouts.json")
let original = ["A", "B", "C"].map { Layout(name: $0, windows: []) }
let app = Harness(file)
app.layouts = original; app.activeIndex = 2
try app.deleteLayout(at: 0)
check(app.layouts.map(\\.name) == ["B", "C"], "keep remaining layout order")
check(app.activeIndex == 1, "selected layout follows its shifted index")
let persisted = try JSONDecoder().decode([Layout].self, from: Data(contentsOf: file))
check(persisted.map(\\.name) == ["B", "C"], "deletion survives reloading from disk")
try app.deleteLayout(at: 1)
check(app.activeIndex == nil, "deleting selected layout clears selection")
try app.deleteLayout(at: 0)
check(app.layouts.isEmpty && app.rebuilds == 3, "last deletion refreshes the empty menu state")
let empty = try JSONDecoder().decode([Layout].self, from: Data(contentsOf: file))
check(empty.isEmpty, "last deletion persists an empty list")
app.layouts = original; app.activeIndex = 0
try app.deleteLayout(at: 2)
check(app.activeIndex == 0, "deleting a later layout preserves selection")
app.layouts = original; app.activeIndex = 2
app.file = folder.appendingPathComponent("missing/layouts.json")
let before = app.rebuilds
var threw = false
do { try app.deleteLayout(at: 0) } catch { threw = true }
check(threw, "failed persistence is reported to the caller")
check(app.layouts.map(\\.name) == ["A", "B", "C"] && app.activeIndex == 2 && app.rebuilds == before, "failed write preserves all live state")
try app.deleteLayout(at: 99)
check(app.rebuilds == before, "invalid index is ignored")
print("PASS: deletion persistence, ordering, selection, empty state, and write-failure rollback")
'''
build = root / '.build/deletion-test'
build.mkdir(parents=True, exist_ok=True)
path = build / 'main.swift'
path.write_text(fixture)
flags = []
if (root / '.build/overlay.json').exists():
    flags = ['-vfsoverlay', str(root / '.build/overlay.json')]
subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', str(root / '.build/module-cache2'), *flags, str(path), '-o', str(build / 'deletion-test')], check=True)
subprocess.run([str(build / 'deletion-test')], check=True)
