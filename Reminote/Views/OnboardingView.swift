import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page: Int = 0

    // Page 0 animation
    @State private var title0Opacity: Double = 0
    @State private var sub0Opacity:   Double = 0
    @State private var cta0Opacity:   Double = 0

    // Page 1 animation (name)
    @State private var title1Opacity: Double = 0
    @State private var field1Opacity: Double = 0
    @State private var cta1Opacity:   Double = 0
    @State private var userName: String = ""
    @FocusState private var nameFocused: Bool

    // Page 2 animation
    @State private var quoteOpacity:     Double = 0
    @State private var quoteLineOpacity: Double = 0
    @State private var startOpacity:     Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StarfieldView()

            Group {
                if page == 0 {
                    page0
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                } else if page == 1 {
                    page1
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                } else {
                    page2
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.45), value: page)
        }
        .preferredColorScheme(.dark)
        .onAppear { animatePage0() }
    }

    // MARK: - Page 0 — Welcome

    private var page0: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Text("Write to your\nfuture self.")
                    .font(.serif(42))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .opacity(title0Opacity)

                Text("One day, this will\ncome back to you.")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(sub0Opacity)
            }
            Spacer()
            Spacer()

            Button {
                Haptic.light()
                page = 1
                animatePage1()
            } label: {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(Color(red: 0.82, green: 0.70, blue: 0.45))
                .clipShape(Capsule())
            }
            .opacity(cta0Opacity)

            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Page 1 — Name

    private var page1: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("What should we\ncall you?")
                        .font(.serif(36))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .opacity(title1Opacity)

                    Text("Your name stays private, on your device only.")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .opacity(title1Opacity)
                }

                // Name field
                VStack(spacing: 0) {
                    TextField("", text: $userName, prompt: Text("Your first name").foregroundColor(.white.opacity(0.3)))
                        .font(.serif(26))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { advanceToPage2() }
                        .padding(.vertical, 16)

                    Rectangle()
                        .fill(userName.isEmpty ? Color.white.opacity(0.15) : Color(red: 0.82, green: 0.70, blue: 0.45))
                        .frame(height: 1)
                        .animation(.easeInOut(duration: 0.2), value: userName.isEmpty)
                }
                .opacity(field1Opacity)
            }

            Spacer()
            Spacer()

            VStack(spacing: 14) {
                Button {
                    advanceToPage2()
                } label: {
                    Text(userName.isEmpty ? "Skip" : "Hello, \(userName) →")
                        .font(.system(size: 17, weight: userName.isEmpty ? .regular : .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 16)
                        .background(userName.isEmpty ? Color.white.opacity(0.5) : Color.white)
                        .clipShape(Capsule())
                }
                .animation(.easeInOut(duration: 0.2), value: userName.isEmpty)

                if !userName.isEmpty {
                    Button {
                        userName = ""
                        nameFocused = true
                    } label: {
                        Text("Change name")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .opacity(cta1Opacity)

            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Page 2 — Example message

    private var page2: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("1 year ago")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.82, green: 0.70, blue: 0.45))
                            .tracking(1.5)
                        Spacer()
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.82, green: 0.70, blue: 0.45))
                    }
                    Text("I'm scared and excited about what's coming. I hope future me remembers why this all mattered.")
                        .font(.serif(20))
                        .foregroundColor(Color(red: 0.97, green: 0.93, blue: 0.85))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .opacity(quoteOpacity)

                Text("\"I didn't expect this.\"")
                    .font(.serif(16, italic: true))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(quoteLineOpacity)
            }

            Spacer()
            Spacer()

            Button {
                Haptic.success()
                if !userName.isEmpty {
                    UserProfileManager.shared.userName = userName
                }
                onComplete()
            } label: {
                let name = userName.isEmpty ? "" : ", \(userName)"
                Text("Start writing\(name)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .opacity(startOpacity)

            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func advanceToPage2() {
        nameFocused = false
        if !userName.isEmpty {
            UserProfileManager.shared.userName = userName
        }
        Haptic.light()
        page = 2
        animatePage2()
    }

    // MARK: - Animations

    private func animatePage0() {
        withAnimation(.easeOut(duration: 0.9).delay(0.3)) { title0Opacity = 1 }
        withAnimation(.easeOut(duration: 0.9).delay(0.8)) { sub0Opacity = 1 }
        withAnimation(.easeOut(duration: 0.9).delay(1.4)) { cta0Opacity = 1 }
    }

    private func animatePage1() {
        title1Opacity = 0; field1Opacity = 0; cta1Opacity = 0
        withAnimation(.easeOut(duration: 0.7).delay(0.1)) { title1Opacity = 1 }
        withAnimation(.easeOut(duration: 0.7).delay(0.4)) { field1Opacity = 1 }
        withAnimation(.easeOut(duration: 0.7).delay(0.7)) { cta1Opacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { nameFocused = true }
    }

    private func animatePage2() {
        quoteOpacity = 0; quoteLineOpacity = 0; startOpacity = 0
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) { quoteOpacity = 1 }
        withAnimation(.easeOut(duration: 0.8).delay(0.7)) { quoteLineOpacity = 1 }
        withAnimation(.easeOut(duration: 0.8).delay(1.1)) { startOpacity = 1 }
    }
}

// MARK: - Starfield

struct StarfieldView: View {
    private struct Star: Identifiable {
        let id = UUID()
        let x, y, size: CGFloat
        let opacity, delay: Double
    }

    private let stars: [Star] = (0..<80).map { _ in
        Star(
            x: .random(in: 0...1), y: .random(in: 0...1),
            size: .random(in: 1...2.5),
            opacity: .random(in: 0.1...0.5), delay: .random(in: 0...4)
        )
    }

    @State private var twinkle = false

    var body: some View {
        GeometryReader { geo in
            ForEach(stars) { s in
                Circle().fill(Color.white)
                    .frame(width: s.size, height: s.size)
                    .position(x: s.x * geo.size.width, y: s.y * geo.size.height)
                    .opacity(twinkle ? s.opacity : s.opacity * 0.4)
                    .animation(
                        .easeInOut(duration: .random(in: 2...4))
                        .repeatForever(autoreverses: true).delay(s.delay),
                        value: twinkle
                    )
            }
        }
        .ignoresSafeArea()
        .onAppear { twinkle = true }
    }
}

#Preview { OnboardingView(onComplete: {}) }
