import SwiftUI

struct CameraView: View {
    @ObservedObject var camera: Camera
    @State private var hingeStatus: DeviceHinge.Status?
    @State private var showingLast = false

    var body: some View {
        GeometryReader { geometry in
            let fold = geometry.reservedRegions(kind: .division, options: .includeInactive,
                                                layoutDirectionBehavior: .fixed).first
            let layout = layout(in: geometry, fold: fold)
            let layoutKey = "status=\(hingeName) size=\(geometry.size) fold=\(String(describing: fold?.frame)) active=\(fold?.isActive ?? false)"

            ZStack(alignment: .topLeading) {
                Color.black

                PreviewSurface(renderer: camera.preview, crop: camera.lens == .crop, name: "inner")
                    .background(.black)
                    .accessibilityIdentifier("monochrome-viewfinder")
                    .frame(width: layout.preview.width, height: layout.preview.height)
                    .clipped()
                    .position(x: layout.preview.midX, y: layout.preview.midY)
                    .sceneAccessory {
                        CameraCaptureAccessory(isEnabled: .constant(hingeStatus == .fullyOpen)) {
                            PreviewSurface(renderer: camera.preview, crop: camera.lens == .crop, name: "accessory")
                                .background(.black)
                                .ignoresSafeArea()
                                .preferredColorScheme(.dark)
                        }
                        .onAvailabilityChange { print("ACCESSORY available=\($0)") }
                    }

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
            .onChange(of: layoutKey, initial: true) { _, key in
                print("LAYOUT \(key) preview=\(layout.preview) controls=\(layout.controls) photo=\(String(describing: layout.photo))")
            }
        }
        .ignoresSafeArea()
        .onHingeChange { _, context in
            let status = context.hinge?.status
            print("HINGE callback status=\(String(describing: status))")
            guard status != hingeStatus else { return }
            hingeStatus = status
            print("HINGE status=\(hingeName)")
        }
        .statusBarHidden()
    }

    private var hingeName: String {
        if hingeStatus == .closed { return "closed" }
        if hingeStatus == .partiallyOpen { return "partiallyOpen" }
        if hingeStatus == .fullyOpen { return "fullyOpen" }
        return "none"
    }

    private func layout(in geometry: GeometryProxy, fold: ReservedRegion?) -> (preview: CGRect, controls: CGRect, photo: CGRect?) {
        let bounds = CGRect(origin: .zero, size: geometry.size)
        var preview = bounds
        var controlPanel = bounds
        var photo: CGRect?
        let splitPhoto = hingeStatus == .fullyOpen

        if let fold, splitPhoto || hingeStatus == .partiallyOpen {
            let sideBySide = fold.frame.height > fold.frame.width
            let length = sideBySide ? bounds.width : bounds.height
            let start = max(0, min(length, sideBySide ? fold.frame.minX : fold.frame.minY))
            let end = max(start, min(length, sideBySide ? fold.frame.maxX : fold.frame.maxY))
            let second: CGRect

            if sideBySide {
                preview = CGRect(x: 0, y: 0, width: start, height: bounds.height)
                second = CGRect(x: end, y: 0, width: length - end, height: bounds.height)
            } else {
                preview = CGRect(x: 0, y: 0, width: bounds.width, height: start)
                second = CGRect(x: 0, y: end, width: bounds.width, height: length - end)
            }
            controlPanel = splitPhoto ? preview : second
            photo = splitPhoto ? second : nil
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
