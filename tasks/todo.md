# RADAR.Speed — Todo

See `docs/DESIGN.md`.

## Phase 0 — Validate hardware assumptions (blocks everything)
- [x] Create Xcode project (iOS 26, Swift 6, SwiftUI). `RadarKit` package deferred until watchOS needs it
- [x] Port parser from CyclometerAI `VariaRadarClient.parseAlert` + Swift Testing tests (5 pass)
- [x] Capture app: auto-connect/remember radar, subscribe to every notify characteristic, read readable ones, CSV log, per-vehicle peak stats, Mark, Share
- [x] **(Brian)** Field capture #1 (2026-09-30): stationary roadside, 10 vehicles
- [x] Findings recorded in DESIGN.md §5; capture checked in as a replay test fixture (4 tests pass)
- [ ] **Open:** what speeds were Marks 1/2 for? Which vehicle was the known-speed pass? This decides between the speed byte and range-rate speed
- [ ] **Open:** why did the radar disconnect (you powered it off, or it auto-off)?
- [ ] **Open:** was there receding traffic in view? Edge-conflict and handheld tests not run yet

## Phase 1 — MVP
- [ ] `VariaPacket` parser + unit tests from captured fixtures
- [ ] `RadarTracker` (peak speed, vehicle departure) + unit tests
- [ ] `RadarConnection` (scan / connect / reconnect / AsyncStream)
- [ ] `RadarModel` (@Observable, @MainActor)
- [ ] `RadarFieldView` (distance axis, car markers, animated)
- [ ] Recent-vehicles strip
- [ ] Settings sheet (find / link / forget, battery)
- [ ] Empty + disconnected states, idle timer

## Phase 2
- [ ] watchOS standalone app on RadarKit
- [ ] Lateral placement if `3204` provides X

## Review
_(fill in after each phase)_
