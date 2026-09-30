import Foundation
import Testing
@testable import RADARSpeed

/// Replays real RTL515 frames captured at the roadside on 2026-09-30 (radar stationary on a
/// tripod, ~2 m from the lane, 10 approaching vehicles). See DESIGN.md §5 "Phase 0 findings".
struct CaptureReplayTests {
    /// Every `6A4E3203` payload in the capture, in arrival order.
    static let frames: [Data] = {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Captures/2026-09-30-roadside.csv")
        let lines = (try? String(contentsOf: url, encoding: .utf8))?.split(separator: "\n") ?? []
        return lines.compactMap { line in
            let fields = line.split(separator: ",", maxSplits: 4)
            guard fields.count == 5, fields[2] == "frame", fields[3] == "6A4E3203" else { return nil }
            let hex = fields[4].dropFirst().prefix { $0 != "|" }
            return Data(hex.split(separator: " ").compactMap { UInt8($0, radix: 16) })
        }
    }()

    @Test func captureLoaded() {
        #expect(Self.frames.count == 1541)
    }

    /// The only frames that aren't `1 + 3n` are the `03 FE` status frames the radar sends for
    /// several seconds after power-on, before any target frames.
    @Test func everyFrameParsesExceptStartupStatus() {
        let rejected = Self.frames.filter { VariaPacket.parse($0) == nil }
        #expect(rejected.count == 106)
        #expect(rejected.allSatisfy { $0 == Data([0x03, 0xFE]) })
    }

    @Test func tracksTenVehiclesWithHighBitThreatIDs() {
        let ids = Set(Self.frames.compactMap(VariaPacket.parse).flatMap { $0.map(\.id) })
        #expect(ids.count == 10)
        #expect(ids.allSatisfy { $0 & 0x80 != 0 })
    }

    /// No tracked vehicle's range ever grows by more than a metre of jitter: every track is an approach.
    @Test func rangesOnlyClose() {
        var last: [UInt8: Int] = [:]
        for targets in Self.frames.compactMap(VariaPacket.parse) {
            for target in targets {
                if let previous = last[target.id] { #expect(target.rangeMetres <= previous + 1) }
                last[target.id] = target.rangeMetres
            }
        }
    }
}
