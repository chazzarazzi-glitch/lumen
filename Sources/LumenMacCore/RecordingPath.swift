import Foundation

public enum RecordingPath {
    public static func libraryURL(fileManager: FileManager = .default) throws -> URL {
        let movies = fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Movies", isDirectory: true)
        let library = movies.appendingPathComponent("Lumen", isDirectory: true)
        try fileManager.createDirectory(at: library, withIntermediateDirectories: true)
        return library
    }

    public static func nextURL(
        now: Date = Date(),
        fileManager: FileManager = .default,
        library: URL? = nil
    ) throws -> URL {
        let directory = try library ?? libraryURL(fileManager: fileManager)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stem = "Lumen-\(formatter.string(from: now))"

        var candidate = directory.appendingPathComponent(stem).appendingPathExtension("mp4")
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem)-\(suffix)").appendingPathExtension("mp4")
            suffix += 1
        }
        return candidate
    }
}
