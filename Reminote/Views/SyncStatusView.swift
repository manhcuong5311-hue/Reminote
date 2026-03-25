import SwiftUI

// MARK: - Animated sync dot (used in the message list header)

struct SyncDotView: View {
    let state: CloudSyncState

    @State private var rotating = false
    @State private var pulse    = false

    var body: some View {
        HStack(spacing: 5) {
            icon
            Text(state.label)
                .font(.system(size: 11))
                .foregroundColor(labelColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(labelColor.opacity(0.1))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(labelColor)
                .rotationEffect(.degrees(rotating ? 360 : 0))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotating = true
                    }
                }

        case .synced:
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 10))
                .foregroundColor(labelColor)

        case .unavailable, .error:
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 10))
                .foregroundColor(labelColor)

        default:
            Image(systemName: "icloud")
                .font(.system(size: 10))
                .foregroundColor(labelColor)
        }
    }

    private var labelColor: Color {
        switch state {
        case .syncing:          return .appAccent
        case .synced:           return Color(red: 0.3, green: 0.75, blue: 0.45)
        case .unavailable:      return .appHint
        case .error:            return .orange
        case .idle, .unknown:   return .appHint
        }
    }
}

// MARK: - Full sync status banner (used in Settings)

struct SyncStatusBanner: View {
    @State private var cloud = iCloudManager.shared

    var body: some View {
        if cloud.isSyncEnabled {
            HStack(spacing: 12) {
                cloudIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appText)
                    Text(cloud.syncState.label)
                        .font(.system(size: 12))
                        .foregroundColor(.appSubtext)
                }
                Spacer()
                if cloud.syncState.isSyncing {
                    ProgressView()
                        .tint(.appAccent)
                        .scaleEffect(0.8)
                }
            }
            .padding(14)
            .cardStyle()
        }
    }

    private var cloudIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.3, green: 0.55, blue: 0.95).opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: "icloud.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.3, green: 0.55, blue: 0.95))
        }
    }
}
