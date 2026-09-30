import SwiftUI

@main
struct RADARSpeedApp: App {
    @State private var session = CaptureSession()

    var body: some Scene {
        WindowGroup {
            CaptureView(session: session)
                .task { session.start() }
        }
    }
}
