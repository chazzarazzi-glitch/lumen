import Foundation
import Testing
@testable import LumenMacCore

@Test func createsLibraryAndUsesMP4Extension() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let date = Date(timeIntervalSince1970: 0)
    let first = try RecordingPath.nextURL(now: date, library: root)
    #expect(first.pathExtension == "mp4")
    #expect(first.lastPathComponent.hasPrefix("Lumen-"))

    FileManager.default.createFile(atPath: first.path, contents: Data())
    let second = try RecordingPath.nextURL(now: date, library: root)
    let firstStem = first.deletingPathExtension().lastPathComponent
    #expect(second.lastPathComponent == "\(firstStem)-2.mp4")
}
