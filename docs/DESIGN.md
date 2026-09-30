# RADAR.Speed — Design (v0.1, draft)

Status: draft for review. Nothing implemented yet.
Confidence tags: **[Certain]**, **[Likely]**, **[Guessing]**.

---

## 1. What the Varia actually gives us (drives everything else)

| Fact | Confidence | Source |
|---|---|---|
| Radar GATT service `6A4E3200-667B-11E3-949A-0800200C9A66` | [Certain] | CyclometerAI, real RTL515 |
| Radar notify characteristic `6A4E3203-…` (not `3202` as some docs say) | [Certain] | CyclometerAI, real RTL515 |
| Packet = 1 header byte + N × 3 bytes `{threatId, range_m, closing_kmh}`, all unsigned `UInt8`; empty frame = header only | [Certain] | CyclometerAI `VariaRadarClient.parseAlert` + ride captures |
| Threat ID is stable per vehicle while it's tracked | [Certain] | CyclometerAI (#fix for glyph jumping) |
| Threat ID: only low 6 bits identify the track; top 2 bits look like metadata | [Guessing] | pycycling issue #25 |
| Speed resolution = 1 km/h; distance resolution = 1 m; first sighting at 87–135 m | [Certain] | CyclometerAI `RadarPassFixtures` |
| Frames arrive ~8 Hz while a vehicle is in range | [Certain] | CyclometerAI BLE.md §15 |
| Capability characteristic is `6A4E3205-…` (payload unknown) | [Likely] | CyclometerAI |
| Peak closing speed occurs at first sighting; cos(θ) decay costs 13–27 km/h by the time the car is alongside | [Certain] (on a bike) | CyclometerAI `VehiclePassDetector` |
| Reported speed may read ~5 km/h high | [Guessing] | one report (pycycling #25) |
| **Only approaching targets are reported**; a vehicle drops off after it passes | [Likely] | product design (rear threat warning) + reviews |
| Speed is **closing speed** (relative to the radar), not ground speed | [Likely] | Garmin behavior on a moving bike |
| No lateral position in V1 — distance only | [Likely] | packet has no field for it |
| A newer `6A4E3204-…` characteristic may carry 9-byte targets with lateral offset (X) and a target class | [Guessing] | rale/radarble, not verified on our hardware |

### Answer to the README question
> Does the Garmin RADAR show vehicles moving away or only coming towards?

**Only approaching vehicles [Likely].** It's a rear threat detector. Receding traffic is filtered out, so on a two-way road you'll see only one direction. To measure the other direction, turn the radar around.

### Consequences for the product
1. **Stationary use is the good case.** When the radar isn't moving, closing speed equals vehicle speed. Handheld use is fine as long as you stand still. Walking adds a few km/h of error.
2. **Cosine error (physics, not a bug) [Certain].** Doppler radar measures only the radial component: `measured = true × cos(θ)`. Standing 5 m from the lane reads 99.9 % correct at 100 m but only 71 % at 5 m. **The number to trust is the one taken far away.** So each vehicle's recorded speed should be its **peak** reading, not its last one.
3. **The "radar field" is 1-D in V1.** We know distance, not which lane. Horizontal placement on screen is invented, so we shouldn't pretend it means anything (see §3).
4. **Hardware limit:** 1 km/h resolution, unverified calibration. The app is a curiosity/traffic-awareness tool, **not** a legal radar gun. The UI must never suggest otherwise.

---

## 2. Scope

**Phase 1 (MVP)**
- iPhone app (iOS 26, Swift 6, SwiftUI, strict concurrency).
- Scan, connect, and remember one Varia (RTL515 / RCT715).
- Live radar field: car symbols moving down toward the user at the bottom, each labelled with its speed.
- Per-vehicle peak speed; a short "recent vehicles" list.
- mph/km/h follows the locale (no settings UI; the README says settings has only device linking).

**Phase 2**
- Standalone watchOS app sharing the core package.
- Probe `…3204` for lateral offset → real lane placement.

**Out of scope:** RVR820 (secured protocol), ANT+, logging/export, alerts, cloud.

---

## 3. Screen design

### Primary screen (portrait)

```
┌────────────────────────────────┐
│ RADAR.Speed        ● Varia  ⚙︎ │  toolbar: connection dot + gear
├────────────────────────────────┤
│ 140 m ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │  range gridlines every 25/50 m
│              🚗 62              │  car.fill + speed (live)
│ 100 m ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│                                 │
│  50 m ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│              🚗 48              │
│                                 │
│               ▲                 │  radar/user position (bottom)
├────────────────────────────────┤
│ LAST  58 · 47 · 61 · 39  mph    │  peak speeds of recent vehicles
└────────────────────────────────┘
```

- **Y axis = distance**, linear, 0 m at the bottom and 140 m at the top. Cars approach from the top.
- **X axis:** V1 has no lateral data. Options:
  - **(A, recommended)** A single center lane. Overlapping cars are separated only when their distance labels would collide, by nudging them sideways. This is honest.
  - (B) A fake lane chosen from `threatId % 3`. It looks nicer but is misleading.
- **Symbol:** `car.fill`, pointing down (rotate 180° or use `car.side`—TBD visually). Its color comes from speed relative to a threshold (Phase 2; Phase 1 uses one color).
- **Label:** a large monospaced number from the **live** reading, with a small "peak" figure under it once peak > live.
- **Animation:** positions interpolate between packets (`.animation(.linear(duration: packetInterval))`) so cars glide instead of jumping.
- **When a vehicle leaves** (its ID disappears from the packet), its peak goes into the "LAST" strip.
- **Empty/disconnected states:** "No radar linked → Open Settings". When connected with no targets, show "Road clear".
- **Screen stays awake** while connected (`isIdleTimerDisabled`).

### Settings sheet (gear)
- A "Radar" section showing the linked device name, connection state, and Forget.
- "Find Radar" scans for the radar service UUID and lists peripherals with RSSI. Tap one to link.
- The device's Battery Service (`0x180F`) is shown if available. [Likely] Varia exposes it.
- Nothing else, per the README.

---

## 4. Architecture

```
RADAR.Speed/                        (iOS app target)
  App/  RADARSpeedApp.swift
  UI/   RadarFieldView, VehicleMarker, RecentStrip, SettingsSheet
RadarKit/  (local Swift package — shared with watchOS in Phase 2)
  VariaPacket.swift        pure parser: Data → [RadarTarget]
  RadarTracker.swift       pure state: targets → Vehicle (peak, first/last seen)
  RadarConnection.swift    CoreBluetooth; AsyncStream<[RadarTarget]>
  DeviceStore.swift        remembered peripheral UUID (UserDefaults)
```

- **Parser and tracker are pure value code with no CoreBluetooth dependency.** That makes them fully unit-testable with captured byte arrays. This is where the risk lives.
- **`RadarConnection`** wraps `CBCentralManager`/`CBPeripheral` delegates and exposes `AsyncStream`s. It runs on its own dispatch queue. The boundary is `Sendable` structs.
- **`@Observable @MainActor RadarModel`** consumes the stream, owns the `RadarTracker`, and drives the views.
- **Reconnect:** store `peripheral.identifier`. Call `retrievePeripherals(withIdentifiers:)` on launch and auto-connect.
- **Background:** Phase 1 is foreground-only. No `bluetooth-central` background mode until there's a reason.
- **Info.plist:** `NSBluetoothAlwaysUsageDescription`.

### Core types
```swift
struct RadarTarget: Sendable, Equatable { let id: UInt8; let distance: Measurement<UnitLength>; let speed: Measurement<UnitSpeed> }
struct Vehicle: Identifiable { let id: UInt8; var distance, speed, peakSpeed; let firstSeen: Date; var lastSeen: Date }
```

---

## 5. Risks / unknowns — resolve with the real device before building UI polish

1. **Does the Varia stream targets when stationary and not paired to an Edge?** [Likely yes] Reviews report it detects while standing still.
2. **Can the phone connect while a Garmin Edge is also connected?** The number of BLE connections the Varia allows is unknown. [Guessing: 1–2]
3. **Does the Varia need a "handshake" write before it notifies?** [Guessing: no for 3203]
4. **Exact header byte meaning, and threat-ID top bits.**
5. **Update rate** (affects animation and peak accuracy).
6. **Speed bias** (+5 km/h report). Calibrate against a car with a known cruise-control speed.
7. **Does `…3204` exist on RTL515/RCT715 firmware, and does it add lateral X?** This would change §3's X-axis decision.

Items 3 and 4 (header byte aside) and 5 are already settled by CyclometerAI. Phase 0 now focuses on 1, 2, 6 and 7, plus whether receding vehicles ever appear.

### Phase 0 findings — capture 2026-09-30 (`RADARSpeedTests/Captures/2026-09-30-roadside.csv`)
Setup: RTL515 (`RTL15451`) stationary at the roadside, 10 approaching vehicles, three connections.

| Finding | Confidence |
|---|---|
| **The radar tracks traffic while stationary.** First sighting at 119–142 m, tracked down to 0–2 m | [Certain] |
| Speed holds within ±1–2 km/h from ~130 m to ~15 m, then drops (cos θ). The drop fits a lane offset of ~2 m | [Certain] / [Likely] |
| **Speed byte reads 6–9 km/h (~14 %) above the range-rate speed** (linear fit of range vs time, frames ≥ 40 m) on every vehicle. One of the two is wrong; a known-speed pass decides which | [Certain] that they disagree; [Guessing] which is right. pycycling #25 found the speed byte reading high |
| Vehicles that brake are tracked down to ~5 km/h (id 145 stopped at 22 m). Range barely moved while the speed byte said 5 km/h, which also hints the speed byte reads high | [Likely] |
| Only `3203` (notify) and `3205` (read+write, value `01`) exist. **No `3204`** on this firmware | [Certain] |
| For about 7 s after power-on the radar sends 2-byte `03 FE` frames, then normal ones. Looks like a warm-up/status frame | [Likely] |
| Header byte: low nibble `2`, bit 7 toggles every frame, bits 4–6 count down every 2 frames. Carries no target data | [Certain] |
| Threat IDs all have bit 7 set (130–189) | [Certain] |
| ~8.3 Hz (120 ms); frames sometimes arrive in pairs (BLE connection-event batching) | [Certain] |
| Battery Level notifies (`0x12`); read 58 % | [Certain] |
| Radar-initiated disconnects at 64 s and ~2 min, then after 10 s. Auto-reconnect worked | [Certain] that they happened; cause unknown |
| No track ever receded, but it isn't known whether receding traffic was present | open |

### Phase 0 field protocol (Capture screen)
1. **Stationary, tripod:** put the Varia at the roadside, 1–3 m from the lane, aimed up the road at approaching traffic. Record 10 or more vehicles.
2. **Known speed:** drive past at a steady cruise-control speed, e.g. 30 and 45 mph, while a helper holds the phone. Tap **Mark** as the car starts its run, and note the speed on paper. This gives a speed bias estimate.
3. **Receding:** turn the radar to face traffic moving *away*. Do any frames appear?
4. **Handheld:** stand still holding the Varia, then walk slowly. Compare the numbers.
5. **Edge conflict:** with the Edge on and paired, does the phone still connect?
6. Share the CSV from the Capture screen, or use Files → On My iPhone → RADAR.Speed. Every notification is logged as raw hex plus the parsed targets. Readable characteristics (e.g. `3205`) and any other notifying characteristic (e.g. `3204`) are logged as well.

**Mitigation:** the first build step is a **raw BLE logger screen**, a debug-only view that shows raw notification bytes and records them to a file. Those captures become the parser's test fixtures.

---

## 6. watchOS (Phase 2) notes
- CoreBluetooth works standalone on watchOS [Certain]. The app must stay foreground, or keep running under an `HKWorkoutSession` / extended runtime session [Likely].
- Same `RadarKit` package. The UI is a vertical distance bar plus a big number for the nearest vehicle's speed.
- It can hold only one BLE link. If the phone is connected to the Varia, the watch probably can't be [Guessing].
