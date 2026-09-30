import Foundation

/// Appends one CSV line per radar event to `Documents/capture-<timestamp>.csv`.
///
/// Phase 0 field-capture tool: the file is visible in the Files app and shareable, and
/// its frames become the parser and tracker test fixtures.
final class CaptureLog {
    let url: URL
    private let handle: FileHandle?
    private let start = Date.now
    private let timestamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    init() {
        let documents = URL.documentsDirectory
        let name = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
            .timeSeparator(.omitted))
        url = documents.appending(path: "capture-\(name).csv")
        FileManager.default.createFile(atPath: url.path(), contents: Data("time,elapsed_s,kind,source,detail\n".utf8))
        handle = try? FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()
    }

    /// `date` defaults to now; a mark passes its tap time so typing the note doesn't shift it.
    func write(kind: String, source: String = "", at date: Date = .now, _ detail: String) {
        let elapsed = String(format: "%.3f", date.timeIntervalSince(start))
        let quoted = detail.replacing("\"", with: "\"\"")
        let line = "\(date.formatted(timestamp)),\(elapsed),\(kind),\(source),\"\(quoted)\"\n"
        try? handle?.write(contentsOf: Data(line.utf8))
    }
}
