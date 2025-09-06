import SwiftUI
import AVKit
import SwiftData

struct MediaDetailView: View {
    let item: MediaItem
    var onClose: (() -> Void)?

    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var tempVideoURL: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            content
                .ignoresSafeArea()

            // Top-right controls
            HStack(spacing: 12) {
                if let processed = item.processedMedia {
                    Button(action: { toggleFavorite(processed) }) {
                        Image(systemName: processed.isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.ultraThinMaterial)
                            .symbolRenderingMode(.palette)
                            .foregroundColor(processed.isFavorited ? .red : .white)
                            .shadow(radius: 4)
                    }
                }
                Button(action: deleteItem) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.ultraThinMaterial)
                        .symbolRenderingMode(.palette)
                        .foregroundColor(.red)
                        .shadow(radius: 4)
                }
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.ultraThinMaterial)
                        .symbolRenderingMode(.palette)
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
            }
            .padding(16)

            // Bottom details overlay
            VStack {
                Spacer()
                details
            }
            .padding()
        }
        .onAppear { preparePlaybackIfNeeded() }
        .onDisappear { cleanupTempFile() }
        .confirmationDialog(
            item.isVideo ? "Delete this video?" : "Delete this photo?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }

    @ViewBuilder
    private var content: some View {
        if item.isVideo, let player {
            VideoPlayer(player: player)
                .onAppear { player.play() }
        } else if let image = primaryImage {
            GeometryReader { geo in
                let size = geo.size
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
            }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.isVideo ? "Video" : "Image")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                if let size = fileSizeString { Text(size) }
                if let dims = dimensionsString { Text(dims) }
                if let dur = durationString { Text(dur) }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.85))

            if let name = fileName {
                Text(name)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var primaryImage: UIImage? {
        if let data = item.processedMedia?.mediaData, !item.isVideo { return UIImage(data: data) }
        if let data = item.photo?.imageData { return UIImage(data: data) }
        return nil
    }

    private var fileName: String? {
        item.processedMedia?.fileName ?? item.photo?.originalFileName
    }

    private var fileSizeString: String? {
        if let bytes = item.processedMedia?.fileSize, bytes > 0 { return Self.formatBytes(bytes) }
        if let bytes = item.photo?.fileSize { return Self.formatBytes(bytes) }
        return nil
    }

    private var dimensionsString: String? {
        if let w = item.processedMedia?.width, let h = item.processedMedia?.height, w > 0, h > 0 { return "\(w)x\(h)" }
        if let w = item.photo?.width, let h = item.photo?.height { return "\(w)x\(h)" }
        return nil
    }

    private var durationString: String? {
        guard let seconds = item.processedMedia?.duration, item.isVideo else { return nil }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func close() {
        onClose?()
        dismiss()
    }

    @State private var showingDeleteConfirm = false
    private func deleteItem() { showingDeleteConfirm = true }

    private func performDelete() {
        if let media = item.processedMedia {
            modelContext.delete(media)
        } else if let photo = item.photo {
            modelContext.delete(photo)
        }
        do { try modelContext.save() } catch { print("MediaDetailView: delete failed: \(error)") }
        close()
    }

    private func toggleFavorite(_ media: ProcessedMedia) {
        media.isFavorited.toggle()
        do { try modelContext.save() } catch { print("MediaDetailView: favorite toggle failed: \(error)") }
    }

    private func preparePlaybackIfNeeded() {
        guard item.isVideo, let data = item.processedMedia?.mediaData else { return }
        // Write to a temporary file to feed AVPlayer
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent((item.processedMedia?.fileName.isEmpty == false ? item.processedMedia!.fileName : UUID().uuidString) + ".mp4")
        do {
            try data.write(to: fileURL, options: .atomic)
            tempVideoURL = fileURL
            let queue = AVQueuePlayer()
            let item = AVPlayerItem(url: fileURL)
            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
        } catch {
            print("Failed to write temp video: \(error)")
        }
    }

    private func cleanupTempFile() {
        player?.pause()
        looper = nil
        if let url = tempVideoURL {
            try? FileManager.default.removeItem(at: url)
            tempVideoURL = nil
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let units: [String] = ["B", "KB", "MB", "GB"]
        var size = Double(bytes)
        var idx = 0
        while size > 1024 && idx < units.count - 1 {
            size /= 1024
            idx += 1
        }
        return String(format: "%.1f %@", size, units[idx])
    }
}
