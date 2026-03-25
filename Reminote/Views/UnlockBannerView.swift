import SwiftUI

struct UnlockBannerView: View {
    let message: Message
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @State private var offset: CGFloat = -220
    @State private var pulseScale: CGFloat = 1.0
    @State private var timerProgress: CGFloat = 1.0

    private let displayDuration: Double = 8

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Pulsing envelope icon
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulseScale)
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.appAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("A message from your past")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appText)
                    if let title = message.title {
                        Text(title)
                            .font(.serif(15))
                            .foregroundColor(.messageCream)
                            .lineLimit(1)
                    } else {
                        Text("is ready to open now")
                            .font(.system(size: 13))
                            .foregroundColor(.appSubtext)
                    }
                }

                Spacer()

                Button {
                    Haptic.success()
                    slideOut { onOpen() }
                } label: {
                    Text("Open")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ThemeManager.shared.current == .softLight ? .white : .black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.appAccent)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Draining progress bar
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.appAccent.opacity(0.45))
                    .frame(width: geo.size.width * timerProgress, height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.linear(duration: displayDuration), value: timerProgress)
            }
            .frame(height: 2)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(0.35), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 14)
        .offset(y: offset)
        .onTapGesture {
            Haptic.light()
            slideOut { onOpen() }
        }
        .onAppear {
            // Slide in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                offset = 0
            }
            // Pulse animation
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulseScale = 1.18
            }
            // Drain the progress bar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                timerProgress = 0
            }
            // Auto-dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
                slideOut(then: nil)
            }
        }
    }

    private func slideOut(then action: (() -> Void)?) {
        withAnimation(.easeInOut(duration: 0.35)) { offset = -220 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            onDismiss()
            action?()
        }
    }
}
