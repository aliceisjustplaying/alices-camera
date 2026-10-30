import AppIntents

struct CameraIntent: CameraCaptureIntent {
    static let title: LocalizedStringResource = "Alice's Camera"

    func perform() async throws -> some IntentResult { .result() }
}
