import Foundation
import CoreGraphics

struct RestoreScreen {
    var key: String
    var builtIn: Bool
    var bounds: CGRect
    var visible: CGRect
    var name: String = ""
    var vendor: UInt32 = 0
    var model: UInt32 = 0
    var serial: UInt32 = 0
}
struct DisplayMapping {
    var screens: [String: RestoreScreen]
    var remapped: Set<String>
    var unavailable: Set<String>
}
struct RestoreWindow {
    var bundle: String
    var title: String
    var index: Int
    var identifier: String? = nil
}
struct RestoreTarget {
    var windowIndex: Int
    var rect: CGRect
    var visible: CGRect
}

enum LayoutRestore {
    /// Convert each screen independently, so primary-screen changes and negative origins work.
    static func visibleFrame(appKitFrame: CGRect, appKitVisible: CGRect, quartzBounds: CGRect) -> CGRect {
        CGRect(x: quartzBounds.minX + appKitVisible.minX - appKitFrame.minX,
               y: quartzBounds.minY + appKitFrame.maxY - appKitVisible.maxY,
               width: appKitVisible.width, height: appKitVisible.height)
    }
    static func mapDisplays(_ placements: [Placement], to screens: [RestoreScreen]) -> DisplayMapping {
        guard let fallback = screens.first(where: { $0.builtIn }) ?? screens.first else {
            return DisplayMapping(screens: [:], remapped: [], unavailable: Set(placements.map(\.display)))
        }
        let saved = Dictionary(grouping: placements, by: \.display).compactMapValues { $0.first }
        var result: [String: RestoreScreen] = [:], used: Set<String> = [], remapped: Set<String> = [], unavailable: Set<String> = []
        func assign(_ key: String, _ screen: RestoreScreen) {
            result[key] = screen; used.insert(screen.key)
            if key != screen.key { remapped.insert(key) }
        }
        // Reserve physical UUID matches first; fallback matching must never steal them.
        for key in saved.keys.sorted() {
            if let screen = screens.first(where: { $0.key == key }) { assign(key, screen) }
        }
        for key in saved.keys.sorted() where result[key] == nil && saved[key]!.builtIn {
            if let screen = screens.first(where: { $0.builtIn && !used.contains($0.key) }) { assign(key, screen) }
        }
        // Mutually unique hardware matches avoid guessing between identical monitors.
        for useSerial in [true, false] {
            var proposals: [String: [RestoreScreen]] = [:]
            for key in saved.keys.sorted() where result[key] == nil && !saved[key]!.builtIn {
                let placement = saved[key]!
                proposals[key] = screens.filter { screen in
                    guard !screen.builtIn, !used.contains(screen.key),
                          placement.displayVendor == screen.vendor, placement.displayModel == screen.model,
                          screen.vendor != 0, screen.model != 0 else { return false }
                    if useSerial { return screen.serial != 0 && placement.displaySerial == screen.serial }
                    // A known serial mismatch is a different physical display.
                    if let serial = placement.displaySerial, serial != 0, screen.serial != 0, serial != screen.serial { return false }
                    return placement.displayName == screen.name && !screen.name.isEmpty
                }
            }
            for key in proposals.keys.sorted() {
                guard let candidates = proposals[key], candidates.count == 1, let screen = candidates.first,
                      proposals.values.filter({ $0.contains(where: { $0.key == screen.key }) }).count == 1 else { continue }
                assign(key, screen)
            }
        }
        let remainingSaved = saved.keys.filter { result[$0] == nil && !saved[$0]!.builtIn }
        let remainingScreens = screens.filter { !$0.builtIn && !used.contains($0.key) }
        // One missing external role and one available external screen is unambiguous,
        // including legacy layouts that predate hardware metadata.
        if remainingSaved.count == 1, remainingScreens.count == 1 { assign(remainingSaved[0], remainingScreens[0]) }
        for key in saved.keys where result[key] == nil { result[key] = fallback; unavailable.insert(key) }
        return DisplayMapping(screens: result, remapped: remapped, unavailable: unavailable)
    }
    /// Match all strong identities before any index fallback. No current window is used twice.
    static func matchWindows(_ saved: [Placement], to current: [RestoreWindow]) -> [Int: Int] {
        var result: [Int: Int] = [:], used: Set<Int> = []
        func assign(_ savedIndex: Int, _ currentIndex: Int) { result[savedIndex] = currentIndex; used.insert(currentIndex) }
        for savedIndex in saved.indices {
            guard let identifier = saved[savedIndex].windowIdentifier, !identifier.isEmpty,
                  saved.filter({ $0.bundle == saved[savedIndex].bundle && $0.windowIdentifier == identifier }).count == 1 else { continue }
            let candidates = current.indices.filter { !used.contains($0) && current[$0].bundle == saved[savedIndex].bundle && current[$0].identifier == identifier }
            if candidates.count == 1 { assign(savedIndex, candidates[0]) }
        }
        for savedIndex in saved.indices where result[savedIndex] == nil && !saved[savedIndex].title.isEmpty {
            let candidates = current.indices.filter { !used.contains($0) && current[$0].bundle == saved[savedIndex].bundle && current[$0].title == saved[savedIndex].title }
            if candidates.count == 1 { assign(savedIndex, candidates[0]) }
            else if let candidate = candidates.first(where: { current[$0].index == saved[savedIndex].index }) { assign(savedIndex, candidate) }
        }
        for savedIndex in saved.indices where result[savedIndex] == nil {
            let candidates = current.indices.filter { !used.contains($0) && current[$0].bundle == saved[savedIndex].bundle && current[$0].index == saved[savedIndex].index }
            if candidates.count == 1 { assign(savedIndex, candidates[0]) }
        }
        for savedIndex in saved.indices where result[savedIndex] == nil {
            let bundle = saved[savedIndex].bundle
            let remaining = saved.indices.filter { result[$0] == nil && saved[$0].bundle == bundle }
            let candidates = current.indices.filter { !used.contains($0) && current[$0].bundle == bundle }
            if remaining.count == 1 && candidates.count == 1 { assign(savedIndex, candidates[0]) }
        }
        return result
    }
    static func target(_ placement: Placement, on screen: RestoreScreen) -> CGRect? {
        let values = [placement.x, placement.y, placement.width, placement.height]
        guard values.allSatisfy({ $0.isFinite }), placement.width > 0, placement.height > 0,
              screen.visible.width > 0, screen.visible.height > 0 else { return nil }
        let base = placement.coordinateSpace == "visible-v1" ? screen.visible : screen.bounds
        let width = min(max(100, placement.width * base.width), screen.visible.width)
        let height = min(max(80, placement.height * base.height), screen.visible.height)
        guard width.isFinite, height.isFinite else { return nil }
        return CGRect(origin: clampedOrigin(CGPoint(x: base.minX + placement.x * base.width, y: base.minY + placement.y * base.height), size: CGSize(width: width, height: height), visible: screen.visible), size: CGSize(width: width, height: height))
    }
    static func clampedOrigin(_ point: CGPoint, size: CGSize, visible: CGRect) -> CGPoint {
        CGPoint(x: max(visible.minX, min(point.x, visible.maxX - size.width)),
                y: max(visible.minY, min(point.y, visible.maxY - size.height)))
    }
    static func matches(_ actual: CGRect?, _ target: CGRect, tolerance: CGFloat = 4) -> Bool {
        guard let actual = actual else { return false }
        return abs(actual.minX-target.minX) <= tolerance && abs(actual.minY-target.minY) <= tolerance && abs(actual.width-target.width) <= tolerance && abs(actual.height-target.height) <= tolerance
    }
}

/// Verify AX results after apps have had time to apply cross-display changes.
/// Bounded retries handle asynchronous resize/move behavior without blocking the menu bar.
final class RestoreRunner {
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> Void
    private var pending: [RestoreTarget]
    private var successes = 0
    private var attempts = 0
    private let apply: (RestoreTarget) -> Void
    private let read: (Int) -> CGRect?
    private let schedule: Schedule
    private let completion: (Int, Int) -> Void
    init(targets: [RestoreTarget], apply: @escaping (RestoreTarget) -> Void, read: @escaping (Int) -> CGRect?, schedule: @escaping Schedule = { delay, work in DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work) }, completion: @escaping (Int, Int) -> Void) {
        self.pending = targets; self.apply = apply; self.read = read; self.schedule = schedule; self.completion = completion
    }
    func start() {
        guard !pending.isEmpty else { completion(0, 0); return }
        attempt()
    }
    private func attempt() {
        attempts += 1
        for target in pending { apply(target) }
        schedule(0.2) { [self] in
            pending = pending.filter { target in
                if LayoutRestore.matches(read(target.windowIndex), target.rect) { successes += 1; return false }
                return true
            }
            if pending.isEmpty || attempts >= 3 { completion(successes, pending.count) }
            else { attempt() }
        }
    }
}
