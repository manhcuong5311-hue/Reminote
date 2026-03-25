import AVFoundation
import Foundation
import Observation

// MARK: - VideoService

@Observable
final class VideoService {

    var isRecording    = false
    var isSessionReady = false
    var recordedURL:   URL?
    var duration:      TimeInterval = 0
    var error:         String?

    private(set) var previewLayer: AVCaptureVideoPreviewLayer

    private let session      = AVCaptureSession()
    private let movieOutput  = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.futuremessage.video.session")
    private let coordinator  = Coordinator()          // NSObject lives here
    private var recordTimer: Timer?
    private var cameraPosition: AVCaptureDevice.Position = .front

    init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        coordinator.owner = self
    }

    // MARK: - Session

    func configure() {
        sessionQueue.async { self.setupSession() }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        if let cam   = camera(for: cameraPosition),
           let input = try? AVCaptureDeviceInput(device: cam),
           session.canAddInput(input) { session.addInput(input) }

        if let mic   = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(input) { session.addInput(input) }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            movieOutput.maxRecordedDuration = CMTime(seconds: 60, preferredTimescale: 600)
        }

        session.commitConfiguration()
        session.startRunning()
        Task { @MainActor in self.isSessionReady = true }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
        Task { @MainActor in self.isSessionReady = false }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        let url = StorageService.shared.newVideoURL()
        movieOutput.startRecording(to: url, recordingDelegate: coordinator)
        isRecording = true
        duration = 0
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.duration += 0.1
            if self.duration >= 60 { self.stopRecording() }
        }
    }

    func stopRecording() {
        recordTimer?.invalidate()
        recordTimer = nil
        movieOutput.stopRecording()
    }

    func discardRecording() {
        if let url = recordedURL { try? FileManager.default.removeItem(at: url) }
        recordedURL = nil
        duration    = 0
    }

    // MARK: - Camera flip

    func flipCamera() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.cameraPosition = self.cameraPosition == .front ? .back : .front

            if let cam   = self.camera(for: self.cameraPosition),
               let input = try? AVCaptureDeviceInput(device: cam),
               self.session.canAddInput(input) { self.session.addInput(input) }

            if let mic   = AVCaptureDevice.default(for: .audio),
               let input = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(input) { self.session.addInput(input) }

            self.session.commitConfiguration()
        }
    }

    // MARK: - Helpers

    var formattedDuration: String {
        String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)
    }

    private func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    // Called back by Coordinator
    fileprivate func didFinishRecording(to url: URL, error: Error?) {
        isRecording = false
        if error == nil { recordedURL = url }
        else { self.error = error?.localizedDescription }
    }
}

// MARK: - Coordinator (NSObject for delegate conformance)

private final class Coordinator: NSObject, AVCaptureFileOutputRecordingDelegate {
    weak var owner: VideoService?

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo url: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.owner?.didFinishRecording(to: url, error: error)
        }
    }
}
