import SwiftUI
import AVFoundation
import AVKit

// MARK: - Camera Preview (UIKit bridge)

struct CameraPreviewView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = PreviewUIView()
        view.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let v = uiView as? PreviewUIView else { return }
        v.previewLayer?.frame = v.bounds
    }

    class PreviewUIView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                if let old = oldValue { old.removeFromSuperlayer() }
                if let new = previewLayer {
                    new.frame = bounds
                    layer.insertSublayer(new, at: 0)
                }
            }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

// MARK: - VideoRecorderView

struct VideoRecorderView: View {
    let onSave: (URL) -> Void
    let onCancel: () -> Void

    @State private var videoService = VideoService()
    @State private var showPreview = false
    @State private var recordProgress: CGFloat = 0

    private let maxDuration: TimeInterval = 60

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showPreview, let url = videoService.recordedURL {
                // Review recorded video
                previewScreen(url: url)
            } else {
                // Live camera
                cameraScreen
            }
        }
        .onAppear {
            videoService.configure()
        }
        .onDisappear {
            videoService.stopSession()
        }
        .onChange(of: videoService.isRecording) { _, recording in
            if !recording && videoService.recordedURL != nil {
                withAnimation { showPreview = true }
            }
        }
        .onChange(of: videoService.duration) { _, d in
            withAnimation(.linear(duration: 0.1)) {
                recordProgress = CGFloat(d / maxDuration)
            }
        }
    }

    // MARK: - Camera screen

    private var cameraScreen: some View {
        ZStack {
            if videoService.isSessionReady {
                CameraPreviewView(layer: videoService.previewLayer)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .overlay(ProgressView().tint(.white))
            }

            // Controls overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        videoService.stopSession()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if videoService.isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 7, height: 7)
                            Text(videoService.formattedDuration)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        videoService.flipCamera()
                        Haptic.light()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                // Progress bar
                if videoService.isRecording {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 3)
                            Rectangle().fill(Color.red).frame(width: geo.size.width * recordProgress, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }

                // Record button
                HStack {
                    Spacer()

                    Button {
                        if videoService.isRecording {
                            videoService.stopRecording()
                            Haptic.medium()
                        } else {
                            videoService.startRecording()
                            Haptic.medium()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)

                            if videoService.isRecording {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.red)
                                    .frame(width: 30, height: 30)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 62, height: 62)
                            }
                        }
                    }
                    .disabled(!videoService.isSessionReady)

                    Spacer()
                }
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Preview screen

    private func previewScreen(url: URL) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(spacing: 20) {
                    Button {
                        videoService.discardRecording()
                        withAnimation { showPreview = false }
                        Haptic.light()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retake")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    Button {
                        onSave(url)
                        Haptic.success()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("Use video")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Video Player View (for message detail)

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(9/16, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear {
                player = AVPlayer(url: url)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}
