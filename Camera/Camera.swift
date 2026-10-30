import AVFoundation
import CoreImage
import Photos
import UIKit
import Combine

final class Camera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum Lens: Int, CaseIterable {
        case ultraWide, main, crop
        var title: String { ["0.5×", "1×", "2×"][rawValue] }
    }

    @Published private(set) var lastShot: UIImage?
    @Published private(set) var lens = Lens.main
    @Published private(set) var ready = false
    @Published private(set) var canCapture = false
    @Published private(set) var busy = false
    @Published private(set) var failed = false

    private let session = AVCaptureSession()
    private let photos = AVCapturePhotoOutput()
    private let video = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera")
    private let frames = DispatchQueue(label: "frames")
    let preview = PreviewRenderer()
    private var input: AVCaptureDeviceInput?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var selected = Lens.main

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            fail("Camera access denied")
            return
        }
        queue.async {
            guard self.input == nil else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            self.video.alwaysDiscardsLateVideoFrames = true
            self.video.setSampleBufferDelegate(self, queue: self.frames)
            self.session.addOutput(self.photos)
            self.session.addOutput(self.video)
            self.session.commitConfiguration()
            self.select(.main)
            self.session.startRunning()
        }
    }

    func setActive(_ active: Bool) {
        queue.async {
            guard self.input != nil else { return }
            if active { self.session.startRunning() }
            else { self.session.stopRunning() }
        }
    }

    func cycleLens() {
        guard !busy, ready else { return }
        ready = false
        canCapture = false
        let next = Lens(rawValue: (lens.rawValue + 1) % Lens.allCases.count)!
        queue.async { self.select(next) }
    }

    private func select(_ lens: Lens) {
        do {
            let type: AVCaptureDevice.DeviceType = lens == .ultraWide ? .builtInUltraWideCamera : .builtInWideAngleCamera
            guard let device = AVCaptureDevice.default(type, for: .video, position: .back) else {
                throw NSError(domain: "Camera", code: 1)
            }
            let replacement = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if let input { session.removeInput(input) }
            guard session.canAddInput(replacement) else {
                if let input { session.addInput(input) }
                session.commitConfiguration()
                throw NSError(domain: "Camera", code: 2)
            }
            session.addInput(replacement)
            input = replacement
            session.commitConfiguration()
            try device.lockForConfiguration()
            device.videoZoomFactor = 1
            if device.activeFormat.isAutoVideoFrameRateSupported {
                device.isAutoVideoFrameRateEnabled = false
            }
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            device.unlockForConfiguration()
            selected = lens
            let raw = photos.availableRawPhotoPixelFormatTypes.filter(AVCapturePhotoOutput.isBayerRAWPixelFormat)
            print("LENS \(lens.title) device=\(device.deviceType.rawValue) zoom=\(device.videoZoomFactor) Bayer=\(raw) ProRAW=\(photos.isAppleProRAWEnabled)")
            if lens == .crop {
                print("RAW_2X software center crop for preview/JPEG; full 1x Bayer DNG; AVCapturePhotoOutput requires videoZoomFactor=1")
            }
            DispatchQueue.main.async {
                let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
                self.rotation = coordinator
                self.rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { coordinator, _ in
                    let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                    self.queue.async {
                        if let connection = self.video.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                            connection.videoRotationAngle = angle
                        }
                        if let connection = self.photos.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                            connection.videoRotationAngle = angle
                        }
                    }
                }
                self.lens = lens
                self.ready = true
                self.canCapture = !raw.isEmpty
                self.failed = raw.isEmpty
            }
        } catch { fail("Lens configuration: \(error)") }
    }

    func capture() {
        guard canCapture, !busy else { return }
        busy = true
        failed = false
        Task {
            guard await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized else {
                fail("Photos add-only access denied")
                return
            }
            queue.async {
                guard let device = self.input?.device, device.videoZoomFactor == 1,
                      let format = self.photos.availableRawPhotoPixelFormatTypes.first(where: AVCapturePhotoOutput.isBayerRAWPixelFormat) else {
                    self.fail("Bayer RAW unavailable")
                    return
                }
                let settings = AVCapturePhotoSettings(rawPixelFormatType: format)
                settings.photoQualityPrioritization = .speed
                settings.flashMode = .off
                self.photos.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        preview.receive(buffer)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { fail("Capture: \(error)"); return }
        guard photo.isRawPhoto, let dng = photo.fileDataRepresentation() else {
            fail("Missing Bayer DNG")
            return
        }
        let lens = selected
        queue.async {
            guard let raw = CIRAWFilter(imageData: dng, identifierHint: "com.adobe.raw-image"), let decoded = raw.outputImage else {
                self.fail("RAW decode failed")
                return
            }
            var monochrome = decoded.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            if lens == .crop {
                monochrome = monochrome.cropped(to: monochrome.extent.insetBy(dx: monochrome.extent.width / 4, dy: monochrome.extent.height / 4))
                monochrome = monochrome.transformed(by: CGAffineTransform(translationX: -monochrome.extent.minX, y: -monochrome.extent.minY))
            }
            guard let rendered = self.preview.context.createCGImage(monochrome, from: monochrome.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)),
                  let jpeg = UIImage(cgImage: rendered).jpegData(compressionQuality: 0.95),
                  let image = UIImage(data: jpeg) else {
                self.fail("JPEG encode failed")
                return
            }
            let name = UUID().uuidString
            let rawURL = URL.temporaryDirectory.appending(path: "\(name).DNG")
            do {
                try dng.write(to: rawURL)
            } catch {
                self.fail("DNG staging: \(error)")
                return
            }
            #if DEBUG
            do {
                let directory = URL.documentsDirectory.appending(path: "Diagnostics")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try dng.write(to: directory.appending(path: "\(lens.rawValue).dng"))
                try jpeg.write(to: directory.appending(path: "\(lens.rawValue).jpg"))
            } catch { print("DIAGNOSTICS \(error)") }
            #endif
            var identifier: String?
            PHPhotoLibrary.shared().performChanges {
                let asset = PHAssetCreationRequest.forAsset()
                let jpgOptions = PHAssetResourceCreationOptions()
                jpgOptions.originalFilename = "\(name).JPG"
                jpgOptions.uniformTypeIdentifier = "public.jpeg"
                let rawOptions = PHAssetResourceCreationOptions()
                rawOptions.originalFilename = "\(name).DNG"
                rawOptions.uniformTypeIdentifier = "com.adobe.raw-image"
                rawOptions.shouldMoveFile = true
                asset.addResource(with: .photo, data: jpeg, options: jpgOptions)
                asset.addResource(with: .alternatePhoto, fileURL: rawURL, options: rawOptions)
                identifier = asset.placeholderForCreatedAsset?.localIdentifier
            } completionHandler: { saved, error in
                try? FileManager.default.removeItem(at: rawURL)
                guard saved else { self.fail("Photos save: \(String(describing: error))"); return }
                print("SAVED asset=\(identifier ?? "nil") lens=\(lens.title) resources=photo:JPEG,alternatePhoto:DNG raw=\(photo.resolvedSettings.rawPhotoDimensions.width)x\(photo.resolvedSettings.rawPhotoDimensions.height) Bayer=true JPEG=\(jpeg.count) DNG=\(dng.count)")
                DispatchQueue.main.async {
                    self.lastShot = image
                    self.busy = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error { fail("Capture completion: \(error)") }
    }

    private func fail(_ message: String) {
        print("ERROR \(message)")
        DispatchQueue.main.async {
            self.busy = false
            self.failed = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
