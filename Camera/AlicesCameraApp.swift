import SwiftUI

@main
struct AlicesCameraApp: App {
    @StateObject private var camera = Camera()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            CameraView(camera: camera)
                .preferredColorScheme(.dark)
                .task { await camera.start() }
                .onChange(of: phase, initial: true) { _, phase in
                    if phase != .inactive {
                        UIApplication.shared.isIdleTimerDisabled = phase == .active
                        camera.setActive(phase == .active)
                    }
                }
        }
    }
}
