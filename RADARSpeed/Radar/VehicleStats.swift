import Foundation

/// What one tracked vehicle did from first to last frame — the numbers Phase 0 needs to see
/// at the roadside (peak speed and where it happened, how close it got, how long it was tracked).
struct VehicleStats: Identifiable {
    let id = UUID()
    let threatID: UInt8
    let firstSeen: Date
    var lastSeen: Date
    let firstRange: Int
    var lastRange: Int
    var currentKPH: Int
    var peakKPH: Int
    var peakAtRange: Int
    var frames = 1

    init(_ target: RadarTarget, at date: Date) {
        threatID = target.id
        firstSeen = date
        lastSeen = date
        firstRange = target.rangeMetres
        lastRange = target.rangeMetres
        currentKPH = target.speedKPH
        peakKPH = target.speedKPH
        peakAtRange = target.rangeMetres
    }

    mutating func update(_ target: RadarTarget, at date: Date) {
        lastSeen = date
        lastRange = target.rangeMetres
        currentKPH = target.speedKPH
        frames += 1
        if target.speedKPH > peakKPH {
            peakKPH = target.speedKPH
            peakAtRange = target.rangeMetres
        }
    }
}
