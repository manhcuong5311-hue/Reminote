import AVFoundation
import Foundation
import Observation

@Observable
final class AudioService: NSObject {
    var isRecording = false
    var isPlaying = false
    var duration: TimeInterval = 0
    var currentPlaybackTime: TimeInterval = 0
    var recordingURL: URL?

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordTimer: Timer?
    private var playTimer: Timer?

    var formattedDuration: String { format(duration) }
    var formattedPlayback: String { format(currentPlaybackTime) }

    // MARK: - Recording

    func requestMicPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func startRecording() -> URL? {
        let url = StorageService.shared.newAudioURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            isRecording = true
            duration = 0
            recordingURL = url
            recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.duration = self?.recorder?.currentTime ?? 0
            }
            return url
        } catch {
            return nil
        }
    }

    func stopRecording() -> URL? {
        recordTimer?.invalidate(); recordTimer = nil
        recorder?.stop()
        isRecording = false
        return recordingURL
    }

    func deleteRecording(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        if recordingURL == url { recordingURL = nil; duration = 0 }
    }

    // MARK: - Playback

    func play(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            isPlaying = true
            currentPlaybackTime = 0
            playTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.currentPlaybackTime = self?.player?.currentTime ?? 0
            }
        } catch {
            isPlaying = false
        }
    }

    func stopPlayback() {
        playTimer?.invalidate(); playTimer = nil
        player?.stop()
        isPlaying = false
        currentPlaybackTime = 0
    }

    // MARK: - Helpers

    private func format(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

extension AudioService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in self.isRecording = false }
    }
}

extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentPlaybackTime = 0
        }
    }
}
