import SwiftUI
import MetalKit
import CoreImage
import AVKit

final class PreviewRenderer: @unchecked Sendable {
    let device = MTLCreateSystemDefaultDevice()!
    let context: CIContext
    let commands: MTLCommandQueue
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let lock = NSLock()
    private var image: CIImage?
    private var sequence = 0

    init() {
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        commands = device.makeCommandQueue()!
    }

    func receive(_ buffer: CVPixelBuffer) {
        let frame = CIImage(cvPixelBuffer: buffer).applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        lock.lock()
        image = frame
        sequence += 1
        lock.unlock()
    }

    func latest() -> (CIImage, Int)? {
        lock.lock()
        defer { lock.unlock() }
        guard let image else { return nil }
        return (image, sequence)
    }
}

struct PreviewSurface: UIViewRepresentable {
    let renderer: PreviewRenderer
    let crop: Bool
    var directionChanged: ((Bool) -> Void)?

    func makeUIView(context: Context) -> MetalPreview {
        MetalPreview(renderer: renderer, directionChanged: directionChanged)
    }

    func updateUIView(_ view: MetalPreview, context: Context) {
        view.crop = crop
    }
}

final class MetalPreview: MTKView, MTKViewDelegate {
    var crop = false
    private let renderer: PreviewRenderer
    private var lastSequence = -1
    private var direction: AVCaptureDeviceDirectionCoordinator?

    init(renderer: PreviewRenderer, directionChanged: ((Bool) -> Void)?) {
        self.renderer = renderer
        super.init(frame: .zero, device: renderer.device)
        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm
        preferredFramesPerSecond = 60
        delegate = self
        if let directionChanged {
            direction = AVCaptureDeviceDirectionCoordinator(view: self, deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera]) { devices in
                directionChanged(devices.forwardFacingDeviceDescriptors.contains { $0.position == .back })
            }
        }
    }

    required init(coder: NSCoder) { fatalError() }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        lastSequence = -1
    }

    func draw(in view: MTKView) {
        guard let (frame, sequence) = renderer.latest(), sequence != lastSequence,
              drawableSize.width > 0, drawableSize.height > 0,
              let drawable = currentDrawable, let command = renderer.commands.makeCommandBuffer() else { return }
        lastSequence = sequence
        var image = frame
        if crop {
            image = image.cropped(to: image.extent.insetBy(dx: image.extent.width / 4, dy: image.extent.height / 4))
        }
        let scale = max(drawableSize.width / image.extent.width, drawableSize.height / image.extent.height)
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        image = image.transformed(by: CGAffineTransform(translationX: (drawableSize.width - image.extent.width) / 2,
                                                       y: (drawableSize.height - image.extent.height) / 2))
        renderer.context.render(image, to: drawable.texture, commandBuffer: command,
                                bounds: CGRect(origin: .zero, size: drawableSize), colorSpace: renderer.colorSpace)
        command.present(drawable)
        command.commit()
    }
}
