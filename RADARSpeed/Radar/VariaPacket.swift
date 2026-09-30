import Foundation

/// One vehicle as the Varia reports it in a single radar frame.
nonisolated struct RadarTarget: Equatable, Sendable {
    /// The radar's own track ID; stable while that vehicle stays tracked.
    let id: UInt8
    let rangeMetres: Int
    /// Closing speed. Equals road speed only while the radar is stationary.
    let speedKPH: Int
}

nonisolated enum VariaPacket {
    /// Parses a notification from the radar characteristic `6A4E3203-…`.
    ///
    /// Layout confirmed against a real RTL515 in CyclometerAI (`VariaRadarClient.parseAlert`):
    /// byte 0 is a header/sequence byte, then 3 bytes per target — threat ID, range in whole
    /// metres, closing speed in whole km/h (unsigned). A frame with no targets is the header alone.
    ///
    /// Returns nil for a length that isn't `1 + 3n`, or for a duplicated threat ID.
    static func parse(_ data: Data) -> [RadarTarget]? {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty, (bytes.count - 1).isMultiple(of: 3) else { return nil }
        let targets = stride(from: 1, to: bytes.count, by: 3).map { i in
            RadarTarget(id: bytes[i], rangeMetres: Int(bytes[i + 1]), speedKPH: Int(bytes[i + 2]))
        }
        guard Set(targets.map(\.id)).count == targets.count else { return nil }
        return targets
    }
}

extension Data {
    nonisolated var hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
