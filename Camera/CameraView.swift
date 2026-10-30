import SwiftUI

struct CameraView: View {
    @ObservedObject var camera: Camera
    @State private var closed = false
    @State private var showingLast = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if closed {
                    compactView
                } else if geometry.size.width > geometry.size.height {
                    HStack(spacing: 2) {
                        viewfinder
                        lastShot
                    }
                } else {
                    VStack(spacing: 2) {
                        viewfinder
                        lastShot
                    }
                }
            }
        }
        .background(HingeObserver(closed: $closed))
        .statusBarHidden()
    }

    private var viewfinder: some View {
        ZStack(alignment: .bottom) {
            feed(name: "inner")
            controls
        }
        .clipped()
        .sceneAccessory {
            CameraCaptureAccessory {
                feed(name: "accessory")
                    .ignoresSafeArea()
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var compactView: some View {
        ZStack(alignment: .bottom) {
            feed(name: "closed").ignoresSafeArea()
            if showingLast, let last = camera.lastShot {
                Image(uiImage: last)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .contentShape(Rectangle())
                    .onTapGesture { showingLast = false }
                    .accessibilityIdentifier("dismiss-last-shot")
            }
            VStack {
                HStack {
                    Spacer()
                    if let last = camera.lastShot, !showingLast {
                        Button { showingLast = true } label: {
                            Image(uiImage: last)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 68, height: 88)
                                .clipped()
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityIdentifier("last-shot")
                    }
                }
                .padding(20)
                Spacer()
                controls
            }
        }
        .background(.black)
        .clipped()
    }

    private func feed(name: String) -> some View {
        PreviewSurface(renderer: camera.preview, crop: camera.lens == .crop, name: name)
        .background(.black)
        .accessibilityIdentifier("monochrome-viewfinder")
    }

    private var lastShot: some View {
        ZStack {
            Color(white: 0.06)
            if let last = camera.lastShot {
                Image(uiImage: last)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("last-shot")
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button { camera.cycleLens() } label: {
                Text(camera.lens.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(width: 58, height: 44)
                    .background(.black.opacity(0.65), in: Capsule())
            }
            .accessibilityIdentifier("lens")
            .disabled(camera.busy || !camera.ready)

            Button { camera.capture() } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 3)
                    Circle().fill(.white).padding(6)
                    if !camera.canCapture && !camera.busy {
                        Image(systemName: "nosign").foregroundStyle(.black)
                    }
                    if camera.busy {
                        ProgressView().tint(.black)
                    }
                }
                .frame(width: 68, height: 68)
            }
            .accessibilityIdentifier("shutter")
            .disabled(!camera.canCapture || camera.busy)
            .opacity(camera.canCapture ? 1 : 0.45)

            Image(systemName: camera.failed ? "exclamationmark.triangle.fill" : "circle.fill")
                .font(.system(size: camera.failed ? 20 : 6))
                .frame(width: 30)
                .opacity(camera.failed ? 1 : 0)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }
}

private struct HingeObserver: UIViewRepresentable {
    @Binding var closed: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.addInteraction(UIHingeInteraction { _, update in
            if let hinge = update.hinge {
                closed = hinge.status == .closed
            }
        })
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
