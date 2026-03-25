import SwiftUI
import AVKit

struct MessageDetailView: View {
    let message: Message
    @Bindable var viewModel: MessageViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var openedMessage:    Message?
    @State private var showUnlockMoment  = false
    @State private var showShareSheet    = false
    @State private var shareImage:       UIImage?
    @State private var showReflect       = false
    @State private var reflectText:      String = ""
    @State private var audioService      = AudioService()
    @State private var appeared          = false
    @State private var showDeleteAlert   = false

    // Export
    @State private var showExportDialog  = false
    @State private var exportItems:      [Any] = []
    @State private var showExportSheet   = false
    @State private var isExporting       = false
    @State private var exportError:      String?
    @State private var showExportError   = false

    private var displayMessage: Message  { openedMessage ?? message }
    private var isOpened: Bool           { displayMessage.isOpened }
    private var isUnlocked: Bool         { displayMessage.isUnlocked }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            if isOpened        { openedView }
            else if isUnlocked { readyToOpenView }
            else               { lockedView }

            if showUnlockMoment {
                UnlockMomentView { withAnimation(.easeInOut(duration: 0.4)) { showUnlockMoment = false } }
                    .transition(.opacity).zIndex(10)
            }
        }
        .preferredColorScheme(ThemeManager.shared.current == .softLight ? .light : .dark)
        // Moment share sheet (card image)
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
        // Export share sheet
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: exportItems)
        }
        // Export picker
        .confirmationDialog("Export message", isPresented: $showExportDialog, titleVisibility: .visible) {
            Button("Export as Text (.txt)")  { export(.text) }
            Button("Export as PDF")          { export(.pdf)  }
            if displayMessage.videoFileName != nil {
                Button("Export Video")       { export(.video) }
            }
            Button("Export All (.zip)")      { export(.zip)  }
            Button("Cancel", role: .cancel)  {}
        }
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Something went wrong.")
        }
        .alert("Delete message?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteMessage(message); dismiss()
            }
        } message: { Text("This cannot be undone.") }
        .onAppear {
            reflectText = displayMessage.reflectNote ?? ""
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { appeared = true }
        }
    }

    // MARK: - Locked

    private var lockedView: some View {
        VStack(spacing: 0) {
            navBar(title: displayMessage.title ?? "Message")
            Divider().background(Color.appBorder)
            Spacer()

            VStack(spacing: 32) {
                ZStack {
                    Circle().fill(Color.appSurface).frame(width: 100, height: 100)
                        .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 38, weight: .thin)).foregroundColor(.appHint)
                }

                VStack(spacing: 12) {
                    Text(displayMessage.countdownString)
                        .font(.serif(28)).foregroundColor(.appText)
                    Text("You wrote something important here.")
                        .font(.system(size: 15, weight: .light)).foregroundColor(.appSubtext).multilineTextAlignment(.center)
                    Text("Written \(displayMessage.timeAgoString)")
                        .font(.system(size: 13)).foregroundColor(.appHint)
                }

                Text(displayMessage.content)
                    .font(.serif(18)).foregroundColor(.messageCream).lineSpacing(6)
                    .blur(radius: 10).clipped()
                    .overlay(RoundedRectangle(cornerRadius: 12).fill(Color.appBg.opacity(0.3)))
                    .padding(20).cardStyle().padding(.horizontal, 24)
            }

            Spacer()
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Ready to open

    private var readyToOpenView: some View {
        VStack(spacing: 0) {
            navBar(title: displayMessage.title ?? "Message")
            Divider().background(Color.appBorder)
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Text("Your message is ready.")
                        .font(.serif(30)).foregroundColor(.appText)
                    Text("Written \(displayMessage.timeAgoString)")
                        .font(.system(size: 14, weight: .light)).foregroundColor(.appSubtext)
                }
                .multilineTextAlignment(.center)

                Text(displayMessage.content)
                    .font(.serif(18)).foregroundColor(.messageCream).lineLimit(4).lineSpacing(6)
                    .blur(radius: 8)
                    .padding(20).cardStyle().padding(.horizontal, 24)

                Button {
                    Haptic.success()
                    openMessageAction()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.open")
                        Text("Open this message").font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(ThemeManager.shared.current == .softLight ? .white : .black)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(ThemeManager.shared.current == .softLight ? Color.appAccent : Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
                }
            }

            Spacer()
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Opened view

    private var openedView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                navBar(title: "")
                Divider().background(Color.appBorder)

                VStack(alignment: .leading, spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = displayMessage.title {
                            Text(title).font(.serif(28)).foregroundColor(.appText)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "calendar").font(.system(size: 12))
                            Text("Written \(displayMessage.timeAgoString) · Opened today")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.appHint)
                    }

                    Divider().background(Color.appBorder)

                    // Text content
                    Text(displayMessage.content)
                        .font(.serif(21)).foregroundColor(.messageCream)
                        .lineSpacing(10).frame(maxWidth: .infinity, alignment: .leading)

                    // Audio
                    if let fn = displayMessage.audioFileName {
                        AudioPlaybackRow(
                            audioService: audioService,
                            url: StorageService.shared.audioURL(for: fn)
                        ) {}
                    }

                    // Video
                    if let fn = displayMessage.videoFileName {
                        let url = StorageService.shared.videoURL(for: fn)
                        videoPlayerSection(url: url)
                    }

                    Divider().background(Color.appBorder)
                    reflectSection
                    shareButton
                    exportButton
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)
            }
        }
    }

    private func videoPlayerSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .font(.system(size: 11)).foregroundColor(.appAccent)
                Text("VIDEO NOTE")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.appAccent).tracking(1.2)
            }
            VideoPlayerView(url: url)
        }
    }

    // MARK: - Reflect

    private var reflectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.and.outline").font(.system(size: 12)).foregroundColor(.appAccent)
                Text("REFLECT").font(.system(size: 11, weight: .semibold)).foregroundColor(.appAccent).tracking(1.2)
            }

            if showReflect || !reflectText.isEmpty {
                ZStack(alignment: .topLeading) {
                    if reflectText.isEmpty {
                        Text("How do you feel reading this now?")
                            .font(.serif(17, italic: true)).foregroundColor(.appHint)
                            .padding(.top, 8).padding(.leading, 4).allowsHitTesting(false)
                    }
                    TextEditor(text: $reflectText)
                        .font(.serif(17)).foregroundColor(.messageCream)
                        .scrollContentBackground(.hidden).background(Color.clear)
                        .frame(minHeight: 100).tint(.appAccent)
                        .onChange(of: reflectText) { _, new in
                            viewModel.saveReflection(for: displayMessage, note: new)
                        }
                }
                .padding(16).cardStyle()
            } else {
                Button {
                    Haptic.light()
                    withAnimation { showReflect = true }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 13))
                        Text("Add a reflection").font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.appSubtext).padding(.vertical, 12).padding(.horizontal, 16).cardStyle()
                }
            }
        }
    }

    // MARK: - Share

    private var shareButton: some View {
        Button {
            Haptic.medium()
            shareImage = ShareImageService.generate(for: displayMessage)
            showShareSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 15))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share this moment").font(.system(size: 15, weight: .semibold))
                    Text("\"I didn't expect this.\"").font(.serif(12, italic: true)).foregroundColor(.appSubtext)
                }
                Spacer()
            }
            .foregroundColor(.appText).padding(16).cardStyle()
        }
    }

    // MARK: - Export button

    private var exportButton: some View {
        Button {
            Haptic.light()
            showExportDialog = true
        } label: {
            HStack(spacing: 10) {
                if isExporting {
                    ProgressView()
                        .tint(.appAccent)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 15))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export message")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Text, PDF, Video, or ZIP")
                        .font(.system(size: 12))
                        .foregroundColor(.appSubtext)
                }
                Spacer()
            }
            .foregroundColor(.appText)
            .padding(16)
            .cardStyle()
        }
        .disabled(isExporting)
    }

    // MARK: - Export logic

    private enum ExportKind { case text, pdf, video, zip }

    private func export(_ kind: ExportKind) {
        isExporting = true
        Haptic.medium()

        Task.detached(priority: .userInitiated) {
            do {
                let items: [Any]
                let msg = await MainActor.run { displayMessage }

                switch kind {
                case .text:
                    items = await [try ExportService.textURL(for: msg)]
                case .pdf:
                    items = await [try ExportService.pdfURL(for: msg)]
                case .video:
                    guard let url = await ExportService.videoURL(for: msg) else {
                        throw ExportError.noVideo
                    }
                    items = [url]
                case .zip:
                    items = await [try ExportService.zipURL(for: msg)]
                }

                await MainActor.run {
                    exportItems    = items
                    isExporting    = false
                    showExportSheet = true
                    Haptic.success()
                }
            } catch {
                await MainActor.run {
                    isExporting   = false
                    exportError   = error.localizedDescription
                    showExportError = true
                    Haptic.error()
                }
            }
        }
    }

    // MARK: - Nav Bar

    private func navBar(title: String) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.appSubtext)
                    .padding(10).background(Color.appSurface).clipShape(Circle())
            }
            Spacer()
            if !title.isEmpty {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.appSubtext)
            }
            Spacer()
            Menu {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16)).foregroundColor(.appSubtext)
                    .padding(10).background(Color.appSurface).clipShape(Circle())
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    // MARK: - Open action

    private func openMessageAction() {
        withAnimation(.easeInOut(duration: 0.3)) { showUnlockMoment = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            openedMessage = viewModel.openMessage(message)
            withAnimation(.easeInOut(duration: 0.4)) { showUnlockMoment = false }
        }
    }
}

// MARK: - Unlock Moment

struct UnlockMomentView: View {
    let onDone: () -> Void

    @State private var particleScale:  CGFloat = 0.1
    @State private var envelopeOpacity: Double = 0
    @State private var envelopeScale:  CGFloat = 0.5
    @State private var bgOpacity:       Double = 0
    @State private var textOpacity:     Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(bgOpacity).ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(Color(red: 0.82, green: 0.70, blue: 0.45).opacity(0.08 - Double(i) * 0.02), lineWidth: 1)
                            .frame(width: CGFloat(120 + i * 50), height: CGFloat(120 + i * 50))
                            .scaleEffect(particleScale)
                    }
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 70, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.82, green: 0.70, blue: 0.45), .white.opacity(0.8)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(envelopeScale).opacity(envelopeOpacity)
                }
                VStack(spacing: 8) {
                    Text("A message from your past").font(.serif(24)).foregroundColor(.white)
                    Text("\"I forgot I wrote this.\"").font(.serif(16, italic: true)).foregroundColor(.white.opacity(0.55))
                }
                .opacity(textOpacity)
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { bgOpacity = 0.95 }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.55).delay(0.2)) {
                envelopeScale = 1; envelopeOpacity = 1
            }
            withAnimation(.easeOut(duration: 1.2).delay(0.4)) { particleScale = 1 }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) { textOpacity = 1 }
            Haptic.success()
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    let msg = Message(
        content: "I'm scared and excited about everything coming. I hope future me is happy.",
        unlockDate: Date().addingTimeInterval(-86400)
    )
    MessageDetailView(message: msg, viewModel: MessageViewModel())
}
