import SwiftUI
import MetalKit
import CoreImage

final class PreviewRenderer: @unchecked Sendable {
    let device = MTLCreateSystemDefaultDevice()!
    let context: CIContext
    let commands: MTLCommandQueue
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let lock = NSLock()
    private var image: CIImage?
    private var sequence = 0
    private var receivedAt = 0.0
    private var inputFrames = 0
    private var inputStart = CACurrentMediaTime()

    init() {
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        commands = device.makeCommandQueue()!
    }

    func receive(_ buffer: CVPixelBuffer) {
        let frame = CIImage(cvPixelBuffer: buffer).applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        lock.lock()
        image = frame
        sequence += 1
        receivedAt = CACurrentMediaTime()
        lock.unlock()
        inputFrames += 1
        let elapsed = CACurrentMediaTime() - inputStart
        if elapsed >= 5 {
            print("PREVIEW_INPUT fps=\(Double(inputFrames) / elapsed)")
            inputFrames = 0
            inputStart = CACurrentMediaTime()
        }
    }

    func latest() -> (CIImage, Int, Double)? {
        lock.lock()
        defer { lock.unlock() }
        guard let image else { return nil }
        return (image, sequence, receivedAt)
    }
}

struct PreviewSurface: UIViewRepresentable {
    let renderer: PreviewRenderer
    let crop: Bool
    let name: String

    func makeUIView(context: Context) -> MetalPreview {
        MetalPreview(renderer: renderer, name: name)
    }

    func updateUIView(_ view: MetalPreview, context: Context) {
        view.crop = crop
    }
}

final class MetalPreview: MTKView, MTKViewDelegate {
    var crop = false
    private let renderer: PreviewRenderer
    private let name: String
    private var lastSequence = -1
    private let metricsLock = NSLock()
    private var delivered = 0
    private var totalLatency = 0.0
    private var metricsStart = CACurrentMediaTime()

    init(renderer: PreviewRenderer, name: String) {
        self.renderer = renderer
        self.name = name
        super.init(frame: .zero, device: renderer.device)
        framebufferOnly = false
        colorPixelFormat = .bgra8Unorm
        preferredFramesPerSecond = 60
        delegate = self
    }

    required init(coder: NSCoder) { fatalError() }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let (frame, sequence, receivedAt) = renderer.latest(), sequence != lastSequence,
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
        drawable.addPresentedHandler { [weak self] drawable in
            guard drawable.presentedTime > 0 else { return }
            self?.recordDelivery(receivedAt: receivedAt, presentedAt: drawable.presentedTime)
        }
        command.commit()
    }

    private func recordDelivery(receivedAt: Double, presentedAt: Double) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        delivered += 1
        totalLatency += presentedAt - receivedAt
        let elapsed = presentedAt - metricsStart
        if elapsed >= 5 {
            print("PREVIEW_METAL display=\(name) deliveredFPS=\(Double(delivered) / elapsed) meanLatencyMS=\(1000 * totalLatency / Double(delivered))")
            delivered = 0
            totalLatency = 0
            metricsStart = presentedAt
        }
    }
}
