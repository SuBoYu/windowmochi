"""Exercise the real permission action with deterministic macOS trust responses."""
from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/WindowMochi/main.swift').read_text()
start = source.index('    @objc func permission() {')
end = source.index('    @objc func snapshot()', start)
action = source[start:end].replace('@objc ', '').replace('AXIsProcessTrustedWithOptions(', 'fakePrompt(').replace('AXIsProcessTrusted()', 'fakeTrusted()')
fixture = '''import Cocoa
import ApplicationServices
var trusted = false
var promptResult = false
var promptCount = 0
func fakeTrusted() -> Bool { trusted }
func fakePrompt(_ options: CFDictionary) -> Bool { promptCount += 1; return promptResult }
func L(_ key: String, _ args: CVarArg...) -> String { key }
final class Harness {
    var messages: [String] = []
    func message(_ title: String, _ detail: String) { messages.append(title) }
''' + action + '''
}
func check(_ condition: Bool, _ label: String) {
    if !condition { print("FAIL: " + label); exit(1) }
}
let app = Harness()
trusted = true
app.permission()
check(app.messages == ["permission_enabled_title"], "already authorized must show success, not enable-permission guidance")
check(promptCount == 0, "already authorized must not request permission again")
trusted = false; app.messages = []; promptResult = false
app.permission()
check(app.messages == ["allow"], "untrusted process must show recovery guidance")
check(promptCount == 1, "untrusted process must request permission")
app.messages = []; promptResult = true
app.permission()
check(app.messages == ["permission_enabled_title"], "honor trusted return value from the prompt API")
print("PASS: actual permission action handles granted, denied, and newly granted states")
'''
build = root / '.build/permission-test'
build.mkdir(parents=True, exist_ok=True)
path = build / 'main.swift'
path.write_text(fixture)
flags = []
if (root / '.build/overlay.json').exists():
    flags = ['-vfsoverlay', str(root / '.build/overlay.json')]
subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', str(root / '.build/module-cache2'), *flags, str(path), '-o', str(build / 'permission-test')], check=True)
subprocess.run([str(build / 'permission-test')], check=True)
