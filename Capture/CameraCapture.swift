import ExtensionKit
import LockedCameraCapture
import SwiftUI

@main
struct CameraCapture: LockedCameraCaptureExtension {
    @StateObject private var camera = Camera()

    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            CameraView(camera: camera, lockedSession: session)
                .preferredColorScheme(.dark)
        }
    }
}
