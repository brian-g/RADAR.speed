import Foundation
import Testing
@testable import RADARSpeed

@MainActor
struct CaptureMarkTests {
    @Test func markLogsTapTimeAndEscapedNote() throws {
        let session = CaptureSession()
        let tap = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21T14:13:20Z
        session.mark(at: tap, note: "  me \"35\" mph ")
        session.mark(at: tap, note: "")

        let lines = try String(contentsOf: session.log.url, encoding: .utf8).split(separator: "\n")
        #expect(lines.suffix(2).map { $0.split(separator: ",", maxSplits: 2)[2] } == [
            #"mark,,"1: me ""35"" mph""#,
            #"mark,,"2""#,
        ])
        #expect(lines.last?.hasPrefix("2026-09-21T14:13:20.000Z,") == true)
        #expect(session.markCount == 2)
    }
}
