import CoreBluetooth
import Foundation
import Observation

/// Phase 0: logs every radar event to a CSV and keeps per-vehicle stats for the capture screen.
@Observable
final class CaptureSession {
    let connection = RadarConnection()
    let log = CaptureLog()

    private(set) var active: [UInt8: VehicleStats] = [:]
    /// Vehicles that have dropped off the radar, newest first.
    private(set) var finished: [VehicleStats] = []
    private(set) var rawLines: [String] = []
    private(set) var framesPerSecond = 0.0
    private(set) var markCount = 0

    @ObservationIgnored private var recentFrameTimes: [Date] = []

    init() {
        connection.onEvent = { [weak self] event in self?.handle(event) }
    }

    func start() { connection.start() }

    /// Logs a numbered mark at `date` — the moment the button was tapped — with an optional note
    /// such as "me, cruise control 35 mph".
    func mark(at date: Date, note: String) {
        markCount += 1
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = note.isEmpty ? "\(markCount)" : "\(markCount): \(note)"
        log.write(kind: "mark", at: date, detail)
        appendRaw("MARK \(detail)")
    }

    private func handle(_ event: RadarConnection.Event) {
        switch event {
        case .log(let text):
            log.write(kind: "event", text)
            appendRaw(text)
        case .value(let uuid, let data):
            let source = String(uuid.uuidString.prefix(8))
            let targets = uuid == RadarConnection.radarData ? VariaPacket.parse(data) : nil
            let parsed = targets.map { $0.map { "\($0.id):\($0.rangeMetres)m:\($0.speedKPH)kph" }.joined(separator: " ") }
            log.write(kind: "frame", source: source, "\(data.hex)|\(parsed ?? (uuid == RadarConnection.radarData ? "UNPARSED" : ""))")
            if uuid != RadarConnection.radarData { appendRaw("\(source) \(data.hex)") }
            if let targets { track(targets) }
        }
    }

    private func track(_ targets: [RadarTarget]) {
        let now = Date.now
        recentFrameTimes = recentFrameTimes.filter { now.timeIntervalSince($0) < 2 } + [now]
        framesPerSecond = Double(recentFrameTimes.count) / 2

        let present = Set(targets.map(\.id))
        for (id, vehicle) in active where !present.contains(id) {
            finished.insert(vehicle, at: 0)
            active[id] = nil
        }
        for target in targets {
            if active[target.id] == nil {
                active[target.id] = VehicleStats(target, at: now)
            } else {
                active[target.id]?.update(target, at: now)
            }
        }
    }

    private func appendRaw(_ line: String) {
        rawLines.insert("\(Date.now.formatted(.dateTime.hour().minute().second())) \(line)", at: 0)
        if rawLines.count > 100 { rawLines.removeLast() }
    }
}
