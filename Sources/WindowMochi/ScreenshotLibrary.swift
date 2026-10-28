import Foundation
import Darwin

struct ScreenshotFile: Equatable {
    let url: URL
    let date: Date
    let size: Int
}

/// File operations shared by the shelf and isolated filesystem tests.
struct ScreenshotLibrary {
    static let extensions: Set<String> = ["png", "jpg", "jpeg", "tif", "tiff", "heic", "heif", "bmp", "gif"]
    static var suggestedFolder: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WindowMochi/Screenshots", isDirectory: true)
    }
    static func images(in folder: URL, limit: Int = 30) throws -> [ScreenshotFile] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey]
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
            .compactMap { url -> ScreenshotFile? in
                guard extensions.contains(url.pathExtension.lowercased()),
                      let values = try? url.resourceValues(forKeys: keys),
                      values.isRegularFile == true, values.isSymbolicLink != true,
                      let size = values.fileSize, size > 0 else { return nil }
                return ScreenshotFile(url: url, date: values.contentModificationDate ?? .distantPast, size: size)
            }
            .sorted { $0.date == $1.date ? $0.url.lastPathComponent < $1.url.lastPathComponent : $0.date > $1.date }
            .prefix(max(0, limit)).map { $0 }
    }
    static func isMacScreenshot(_ url: URL) -> Bool {
        let name = "com.apple.metadata:kMDItemIsScreenCapture"
        let count = getxattr(url.path, name, nil, 0, 0, XATTR_NOFOLLOW)
        guard count > 0, count < 65_536 else { return false }
        var bytes = [UInt8](repeating: 0, count: count)
        let read = bytes.withUnsafeMutableBytes { getxattr(url.path, name, $0.baseAddress, count, 0, XATTR_NOFOLLOW) }
        guard read == count,
              let value = try? PropertyListSerialization.propertyList(from: Data(bytes), options: [], format: nil) else { return false }
        if let flag = value as? Bool { return flag }
        if let text = value as? String { return ["1", "true", "yes"].contains(text.lowercased()) }
        return false
    }
    static func desktopCandidates(in desktop: URL) throws -> [ScreenshotFile] {
        try images(in: desktop, limit: Int.max).filter { isMacScreenshot($0.url) }
    }
    static func moveScreenshot(_ source: URL, to folder: URL) throws -> URL {
        let manager = FileManager.default
        guard isMacScreenshot(source), source.deletingLastPathComponent().resolvingSymlinksInPath() != folder.resolvingSymlinksInPath() else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw CocoaError(.fileReadUnsupportedScheme) }
        let base = source.deletingPathExtension().lastPathComponent
        for number in 1...10_000 {
            let name = number == 1 ? source.lastPathComponent : "\(base) (\(number)).\(source.pathExtension)"
            let destination = folder.appendingPathComponent(name)
            if manager.fileExists(atPath: destination.path) { continue }
            do { try manager.moveItem(at: source, to: destination); return destination }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { continue }
        }
        throw CocoaError(.fileWriteFileExists)
    }
}
