import SwiftUI
import AVFoundation

struct CreateMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MessageViewModel
    var debugMode: Bool = false

    // Form state
    @State private var title:          String = ""
    @State private var content:        String = ""
    @State private var unlockDate:     Date   = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedPreset: DatePreset? = .oneMonth
    @State private var showCustomDate  = false

    // UX state
    @State private var showLockConfirm = false
    @State private var showLockMoment  = false
    @FocusState private var contentFocused: Bool

    // Audio
    @State private var audioService = AudioService()
    @State private var recordingURL: URL?

    // Video
    @State private var showVideoRecorder = false
    @State private var videoURL: URL?

    // Animation
    @State private var formOpacity: Double = 0

    // Debug countdown
    @State private var debugSecondsLeft: Int = 120
    @State private var debugTimer: Timer?

    // MARK: - Date Preset

    enum DatePreset: String, CaseIterable {
        case oneMonth = "1 month", sixMonths = "6 months", oneYear = "1 year", custom = "Custom"
        func date() -> Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth:  return cal.date(byAdding: .month, value: 1, to: Date())
            case .sixMonths: return cal.date(byAdding: .month, value: 6, to: Date())
            case .oneYear:   return cal.date(byAdding: .year,  value: 1, to: Date())
            case .custom:    return nil
            }
        }
    }

    var canLock: Bool { content.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerBar
                    Divider().background(Color.appBorder).padding(.horizontal, 24)

                    VStack(spacing: 32) {
                        titleField
                        contentField
                        mediaSection
                        Divider().background(Color.appBorder)
                        if debugMode {
                            debugBanner
                        } else {
                            dateSection
                            previewLabel
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .opacity(formOpacity)
                }
            }

            VStack {
                Spacer()
                lockButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                    .background(
                        LinearGradient(colors: [Color.appBg.opacity(0), Color.appBg],
                                       startPoint: .top, endPoint: .bottom)
                        .frame(height: 120).allowsHitTesting(false),
                        alignment: .bottom
                    )
            }
        }
        .preferredColorScheme(ThemeManager.shared.current == .softLight ? .light : .dark)
        .onAppear {
            contentFocused = true
            withAnimation(.easeOut(duration: 0.5)) { formOpacity = 1 }
            if debugMode {
                unlockDate = Date().addingTimeInterval(2 * 60)
                startDebugTimer()
            }
        }
        .onDisappear {
            debugTimer?.invalidate()
        }
        .alert("Lock this message?", isPresented: $showLockConfirm) {
            Button("Cancel", role: .cancel) {}
            Button(debugMode ? "Lock & start test" : "Lock forever", role: .destructive) { lock() }
        } message: {
            if debugMode {
                Text("This debug message will unlock in ~2 minutes. Audio and video are enabled regardless of premium status.")
            } else {
                Text("You won't be able to edit this after locking. It will open on \(unlockDate.formatted(date: .long, time: .omitted)).")
            }
        }
        .overlay {
            if showLockMoment {
                LockMomentView {
                    showLockMoment = false
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showVideoRecorder) {
            VideoRecorderView(
                onSave: { url in
                    videoURL = url
                    showVideoRecorder = false
                },
                onCancel: { showVideoRecorder = false }
            )
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView(viewModel: viewModel)
        }
    }

    // MARK: - Components

    private var headerBar: some View {
        HStack {
            Button { dismiss(); Haptic.light() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appSubtext)
                    .padding(10)
                    .background(Color.appSurface)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(debugMode ? "Debug Test Message" : "New Message")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(debugMode ? .orange : .appSubtext)
                    .tracking(0.5)
                if debugMode {
                    Text("UNLOCKS IN 2 MIN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange.opacity(0.7))
                        .tracking(1)
                }
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var titleField: some View {
        TextField("Title (optional)", text: $title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.appText)
            .padding(.vertical, 4)
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(.appBorder), alignment: .bottom)
    }

    private var contentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            if content.isEmpty {
                let name = UserProfileManager.shared.userName
                Text(name.isEmpty ? "Dear future me," : "Dear future \(name),")
                    .font(.serif(22, italic: true))
                    .foregroundColor(.appHint)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $content)
                .font(.serif(22))
                .foregroundColor(.messageCream)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 200)
                .focused($contentFocused)
                .tint(.appAccent)
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attach media")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appHint)
                .tracking(1)

            // Voice note
            if let url = recordingURL {
                AudioPlaybackRow(audioService: audioService, url: url) {
                    audioService.deleteRecording(url)
                    recordingURL = nil
                }
            } else {
                AudioRecordRow(audioService: audioService, isPremium: debugMode || viewModel.isPremium) {
                    if let url = audioService.startRecording() { recordingURL = url }
                } onStop: {
                    recordingURL = audioService.stopRecording()
                } onPaywall: {
                    viewModel.showPaywall = true
                }
            }

            // Video note
            if let _ = videoURL {
                videoAttachedRow
            } else {
                videoRecordRow
            }
        }
    }

    private var videoRecordRow: some View {
        HStack(spacing: 14) {
            Button {
                if !debugMode && !viewModel.isPremium { viewModel.showPaywall = true; return }
                showVideoRecorder = true
                Haptic.medium()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.appSurface)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
                    Image(systemName: "video.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.appSubtext)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Video note")
                        .font(.system(size: 14))
                        .foregroundColor(.appSubtext)
                    if !viewModel.isPremium { PremiumBadge() }
                }
                Text("Record up to 60 seconds for your future self")
                    .font(.system(size: 11))
                    .foregroundColor(.appHint)
            }
            Spacer()
        }
        .padding(14)
        .cardStyle()
    }

    private var videoAttachedRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "video.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.appAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Video note attached")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appText)
                Text("Tap to preview or re-record")
                    .font(.system(size: 11))
                    .foregroundColor(.appSubtext)
            }

            Spacer()

            Button {
                if let url = videoURL {
                    try? FileManager.default.removeItem(at: url)
                }
                videoURL = nil
                Haptic.light()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(14)
        .cardStyle()
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Open this message")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appHint)
                .tracking(1)

            HStack(spacing: 10) {
                ForEach(DatePreset.allCases, id: \.self) { preset in
                    PresetChip(label: preset.rawValue, selected: selectedPreset == preset) {
                        Haptic.light()
                        selectedPreset = preset
                        if preset == .custom { showCustomDate = true }
                        else if let d = preset.date() { unlockDate = d }
                    }
                }
            }

            if showCustomDate || selectedPreset == .custom {
                DatePicker("", selection: $unlockDate,
                           in: Date().addingTimeInterval(3600)...,
                           displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.appAccent)
                .labelsHidden()
                .colorScheme(ThemeManager.shared.current == .softLight ? .light : .dark)
            }
        }
    }

    private var previewLabel: some View {
        HStack {
            Image(systemName: "clock").font(.system(size: 13)).foregroundColor(.appAccent)
            Text("This message will wait for you until **\(unlockDate.formatted(date: .long, time: .omitted))**")
                .font(.system(size: 13))
                .foregroundColor(.appSubtext)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.appAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var lockButton: some View {
        Button {
            guard canLock else { return }
            Haptic.medium()
            showLockConfirm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.system(size: 15))
                Text("Lock this message").font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(canLock ? (ThemeManager.shared.current == .softLight ? .white : .black) : .appHint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(canLock ? (ThemeManager.shared.current == .softLight ? Color.appAccent : Color.white) : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!canLock)
        .animation(.easeInOut(duration: 0.2), value: canLock)
    }

    // MARK: - Lock

    private func lock() {
        let resolvedTitle = debugMode && title.isEmpty ? "⏱ Debug Test" : (title.isEmpty ? nil : title)
        var message = Message(
            title:      resolvedTitle,
            content:    content.isEmpty && debugMode ? "Debug message with audio/video test." : content,
            unlockDate: unlockDate
        )
        if let url = recordingURL { message.audioFileName = url.lastPathComponent }
        if let url = videoURL     { message.videoFileName = url.lastPathComponent }

        if debugMode {
            viewModel.debugForceCreate(message)
        } else {
            viewModel.createMessage(message)
        }

        withAnimation(.easeInOut(duration: 0.3)) { showLockMoment = true }
        Haptic.success()
    }

    // MARK: - Debug helpers

    private var debugBanner: some View {
        VStack(spacing: 14) {
            // Timer ring + countdown
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 3)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: CGFloat(debugSecondsLeft) / 120)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: debugSecondsLeft)
                    Text("\(debugSecondsLeft)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "ant.fill")
                            .font(.system(size: 10))
                        Text("DEBUG MODE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                    }
                    .foregroundColor(.orange)

                    Text("Unlocks in ~2 minutes. Audio & video unlocked.")
                        .font(.system(size: 12))
                        .foregroundColor(.appSubtext)

                    Text("Write, record audio or video, then lock.")
                        .font(.system(size: 11))
                        .foregroundColor(.appHint)
                }
            }
            .padding(14)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
            )
        }
    }

    private func startDebugTimer() {
        debugSecondsLeft = 120
        debugTimer?.invalidate()
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if debugSecondsLeft > 0 { debugSecondsLeft -= 1 }
            else { debugTimer?.invalidate() }
        }
    }
}

// MARK: - Preset Chip

struct PresetChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? (ThemeManager.shared.current == .softLight ? .white : .black) : .appSubtext)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? Color.appAccent : Color.appSurface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(selected ? .clear : Color.appBorder, lineWidth: 0.5))
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

// MARK: - Audio Record Row

struct AudioRecordRow: View {
    @Bindable var audioService: AudioService
    let isPremium: Bool
    let onStart:   () -> Void
    let onStop:    () -> Void
    let onPaywall: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                if !isPremium { onPaywall(); return }
                if audioService.isRecording { onStop() } else { onStart() }
                Haptic.medium()
            } label: {
                ZStack {
                    Circle()
                        .fill(audioService.isRecording ? Color.red : Color.appSurface)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
                    Image(systemName: audioService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(audioService.isRecording ? .white : .appSubtext)
                }
            }

            if audioService.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text(audioService.formattedDuration)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.appText)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Voice note").font(.system(size: 14)).foregroundColor(.appSubtext)
                        if !isPremium { PremiumBadge() }
                    }
                    Text("Record a message to your future self")
                        .font(.system(size: 11)).foregroundColor(.appHint)
                }
            }
            Spacer()
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - Audio Playback Row

struct AudioPlaybackRow: View {
    @Bindable var audioService: AudioService
    let url: URL
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                Haptic.light()
                if audioService.isPlaying { audioService.stopPlayback() }
                else { audioService.play(url: url) }
            } label: {
                ZStack {
                    Circle().fill(Color.appAccent.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15)).foregroundColor(.appAccent)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Voice note recorded")
                    .font(.system(size: 13, weight: .medium)).foregroundColor(.appText)
                Text(audioService.formattedDuration)
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(.appSubtext)
            }
            Spacer()

            Button {
                audioService.stopPlayback(); onDelete(); Haptic.light()
            } label: {
                Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - Lock Moment Overlay

struct LockMomentView: View {
    let onDone: () -> Void

    @State private var lockScale:   CGFloat = 0
    @State private var lockOpacity: Double  = 0
    @State private var textOpacity: Double  = 0
    @State private var bgOpacity:   Double  = 0
    @State private var glowOpacity: Double  = 0

    var body: some View {
        ZStack {
            Color.black.opacity(bgOpacity).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color(red: 0.82, green: 0.70, blue: 0.45).opacity(0.12 * glowOpacity))
                        .frame(width: 140, height: 140).blur(radius: 20)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(Color(red: 0.82, green: 0.70, blue: 0.45))
                        .scaleEffect(lockScale).opacity(lockOpacity)
                }

                VStack(spacing: 12) {
                    Text("Your message is now waiting for you.")
                        .font(.serif(22)).foregroundColor(.white).multilineTextAlignment(.center)
                    Text("It will find you when the time is right.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(.white.opacity(0.55)).multilineTextAlignment(.center)
                }
                .opacity(textOpacity).padding(.horizontal, 40)

                Spacer()

                Button {
                    withAnimation(.easeIn(duration: 0.3)) { bgOpacity = 0; lockOpacity = 0; textOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDone() }
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                }
                .opacity(textOpacity).padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { bgOpacity = 0.95 }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) {
                lockScale = 1; lockOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) { glowOpacity = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.5)) { textOpacity = 1 }
        }
    }
}

#Preview { CreateMessageView(viewModel: MessageViewModel()) }
