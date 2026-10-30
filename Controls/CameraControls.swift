import SwiftUI
import WidgetKit

@main
struct CameraControls: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aliceisjustplaying.camera.control") {
            ControlWidgetButton(action: CameraIntent()) {
                Label("Alice's Camera", systemImage: "camera")
            }
        }
        .displayName("Alice's Camera")
    }
}
