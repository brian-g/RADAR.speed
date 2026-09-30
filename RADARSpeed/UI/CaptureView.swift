import SwiftUI

/// Phase 0 debug screen: live targets, per-vehicle summaries and the raw event feed, with
/// a Mark button to timestamp field observations and a Share button for the CSV capture.
struct CaptureView: View {
    let session: CaptureSession
    /// When Mark was tapped; non-nil while the note prompt is up.
    @State private var pendingMark: Date?
    @State private var note = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Radar") {
                    LabeledContent("State", value: stateText)
                    LabeledContent("Battery", value: session.connection.batteryPercent.map { "\($0)%" } ?? "—")
                    LabeledContent("Frames/s", value: session.framesPerSecond.formatted(.number.precision(.fractionLength(1))))
                }
                Section("Tracking now") {
                    ForEach(session.active.values.sorted { $0.lastRange < $1.lastRange }) { vehicle in
                        VehicleRow(vehicle: vehicle, live: true)
                    }
                }
                Section("Passed") {
                    ForEach(session.finished) { VehicleRow(vehicle: $0, live: false) }
                }
                Section("Raw") {
                    ForEach(Array(session.rawLines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: session.log.url)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    pendingMark = .now
                } label: {
                    Label("Mark \(session.markCount + 1)", systemImage: "flag.fill")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal)
            }
            .alert("Mark \(session.markCount + 1)", isPresented: Binding(
                get: { pendingMark != nil },
                set: { if !$0 { pendingMark = nil } }
            )) {
                TextField("Note, e.g. me at 35 mph", text: $note)
                Button("Save") {
                    if let pendingMark { session.mark(at: pendingMark, note: note) }
                    note = ""
                }
                Button("Discard", role: .cancel) { note = "" }
            } message: {
                Text("Time recorded at tap: \(pendingMark?.formatted(date: .omitted, time: .standard) ?? "")")
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    }

    private var stateText: String {
        switch session.connection.state {
        case .idle: "Idle"
        case .unavailable(let reason): reason
        case .scanning: "Scanning…"
        case .connecting(let name): "Connecting to \(name)"
        case .connected(let name): "Connected: \(name)"
        }
    }
}

private struct VehicleRow: View {
    let vehicle: VehicleStats
    let live: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("#\(vehicle.threatID)").foregroundStyle(.secondary)
                Text(live ? "\(vehicle.currentKPH) km/h" : "peak \(vehicle.peakKPH) km/h")
                    .font(.title3.monospacedDigit().bold())
                Text("(\(mph(live ? vehicle.currentKPH : vehicle.peakKPH)) mph)").foregroundStyle(.secondary)
                Spacer()
                if live { Text("\(vehicle.lastRange) m").font(.title3.monospacedDigit()) }
            }
            Text("""
                peak \(vehicle.peakKPH) @ \(vehicle.peakAtRange) m · \(vehicle.firstRange)→\(vehicle.lastRange) m · \
                \(vehicle.frames) frames · \
                \(vehicle.lastSeen.timeIntervalSince(vehicle.firstSeen).formatted(.number.precision(.fractionLength(1)))) s
                """)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func mph(_ kph: Int) -> Int { Int((Double(kph) / 1.609_344).rounded()) }
}
