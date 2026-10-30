import SwiftUI

struct CameraView: View {
    @ObservedObject var camera: Camera
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var hingeStatus: DeviceHinge.Status?
    @State private var rearFacesView = false
    @State private var accessoryEnabled = false
    @State private var showingLast = false

    var body: some View {
        GeometryReader { geometry in
            let fold = geometry.reservedRegions(kind: .division, options: .includeInactive,
                                                layoutDirectionBehavior: .fixed).first
            let layout = layout(in: geometry, fold: fold)

            ZStack(alignment: .topLeading) {
                Color.black

                PreviewSurface(renderer: camera.preview, crop: camera.lens == .crop) { facesView in
                    guard facesView != rearFacesView else { return }
                    rearFacesView = facesView
                    print("HANDOFF rearFacesView=\(facesView)")
                }
                    .background(.black)
                    .accessibilityIdentifier("monochrome-viewfinder")
                    .frame(width: layout.preview.width, height: layout.preview.height)
                    .clipped()
                    .position(x: layout.preview.midX, y: layout.preview.midY)

                if let photo = layout.photo {
                    lastShot
                        .frame(width: photo.width, height: photo.height)
                        .position(x: photo.midX, y: photo.midY)
                }

                if layout.photo == nil, showingLast {
                    lastShot
                        .frame(width: layout.preview.width, height: layout.preview.height)
                        .contentShape(Rectangle())
                        .onTapGesture { showingLast = false }
                        .accessibilityIdentifier("dismiss-last-shot")
                        .position(x: layout.preview.midX, y: layout.preview.midY)
                }

                VStack {
                    HStack {
                        Spacer()
                        if layout.photo == nil, !showingLast {
                            thumbnail
                        }
                    }
                    .padding(20)
                    Spacer(minLength: 0)
                    controls
                }
                .frame(width: layout.controls.width, height: layout.controls.height)
                .position(x: layout.controls.midX, y: layout.controls.midY)
            }
            .onChange(of: layout.preview, initial: true) { _, _ in
                print("WINDOW size=\(geometry.size) sizeClass=\(String(describing: sizeClass)) fold=\(String(describing: fold?.frame)) preview=\(layout.preview) controls=\(layout.controls) photo=\(String(describing: layout.photo))")
            }
        }
        .ignoresSafeArea()
        .sceneAccessory {
            CameraCaptureAccessory(isEnabled: $accessoryEnabled) {
                PreviewSurface(renderer: camera.preview, crop: camera.lens == .crop)
                    .background(.black)
                    .ignoresSafeArea()
                    .preferredColorScheme(.dark)
                    .allowsHitTesting(false)
            }
        }
        .onHingeChange { _, context in
            let status = context.hinge?.status
            guard status != hingeStatus else { return }
            hingeStatus = status
        }
        .onChange(of: hingeStatus == .fullyOpen && sizeClass == .regular && !rearFacesView, initial: true) { _, enabled in
            accessoryEnabled = enabled
            print("ACCESSORY enabled=\(enabled)")
        }
        .statusBarHidden()
    }

    private func layout(in geometry: GeometryProxy, fold: ReservedRegion?) -> (preview: CGRect, controls: CGRect, photo: CGRect?) {
        let bounds = CGRect(origin: .zero, size: geometry.size)
        var preview = bounds
        var controlPanel = bounds
        var photo: CGRect?

        if sizeClass == .regular && hingeStatus != .closed && !rearFacesView {
            var sideBySide = bounds.width > bounds.height
            var start = (sideBySide ? bounds.width : bounds.height) / 2
            var end = start
            var atFold = false
            if let frame = fold?.frame {
                let vertical = frame.height > frame.width
                let crosses = vertical
                    ? frame.minX > 0 && frame.maxX < bounds.width && frame.minY <= 0 && frame.maxY >= bounds.height
                    : frame.minY > 0 && frame.maxY < bounds.height && frame.minX <= 0 && frame.maxX >= bounds.width
                if crosses {
                    sideBySide = vertical
                    start = vertical ? frame.minX : frame.minY
                    end = vertical ? frame.maxX : frame.maxY
                    atFold = true
                }
            }
            let second: CGRect

            if sideBySide {
                preview = CGRect(x: 0, y: 0, width: start, height: bounds.height)
                second = CGRect(x: end, y: 0, width: bounds.width - end, height: bounds.height)
            } else {
                preview = CGRect(x: 0, y: 0, width: bounds.width, height: start)
                second = CGRect(x: 0, y: end, width: bounds.width, height: bounds.height - end)
            }
            let controlsBelow = atFold && hingeStatus == .partiallyOpen
            controlPanel = controlsBelow ? second : preview
            photo = controlsBelow ? nil : second
        }

        let insets = geometry.safeAreaInsets
        let safeBounds = CGRect(x: insets.leading, y: insets.top,
                                width: max(0, bounds.width - insets.leading - insets.trailing),
                                height: max(0, bounds.height - insets.top - insets.bottom))
        let controls = controlPanel.intersection(safeBounds)
        return (preview, controls.isNull ? .zero : controls, photo)
    }

    private var thumbnail: some View {
        Group {
            if let last = camera.lastShot {
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
    }

    private var lastShot: some View {
        ZStack {
            Color.black
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
    }
}
