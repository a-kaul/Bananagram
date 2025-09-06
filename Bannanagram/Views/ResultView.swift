import SwiftUI
import SwiftData
import AVKit

struct ResultView: View {
    let originalPhoto: Photo
    let processedMedia: ProcessedMedia
    let suggestion: TransformationSuggestion
    let onComplete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var inlinePlayer: AVQueuePlayer?
    @State private var inlineLooper: AVPlayerLooper?
    @State private var inlineTempURL: URL?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Magic Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(suggestion.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Before/After Comparison
                ScrollView {
                    VStack(spacing: 20) {
                        // Result Image/Video
                        Group {
                            if processedMedia.isVideo {
                                VStack(spacing: 12) {
                                    Text("After (Video)")
                                        .font(.headline)
                                        .foregroundColor(.blue)

                                    if let player = inlinePlayer {
                                        VideoPlayer(player: player)
                                            .onAppear { player.play() }
                                            .onDisappear { player.pause() }
                                            .frame(maxHeight: 300)
                                            .cornerRadius(12)
                                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                            )
                                    } else {
                                        ProgressView()
                                            .frame(height: 200)
                                            .onAppear { prepareInlineVideoIfNeeded() }
                                    }
                                }
                            } else if let mediaData = processedMedia.mediaData,
                                      let resultImage = UIImage(data: mediaData) {
                                VStack(spacing: 12) {
                                    Text("After")
                                        .font(.headline)
                                        .foregroundColor(.blue)

                                    Image(uiImage: resultImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 300)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                        }
                        
                        // Divider
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal)
                        
                        // Original Image
                        if let originalImage = originalPhoto.image {
                            VStack(spacing: 12) {
                                Text("Before")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Image(uiImage: originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(12)
                                    .opacity(0.7)
                            }
                        }
                        
                        // Transformation Details
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                TypeBadge(type: suggestion.type)
                                Spacer()
                                ConfidenceBadge(confidence: suggestion.confidence)
                            }
                            
                            Text(suggestion.suggestionDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            if !suggestion.reasoning.isEmpty {
                                Text("Why this transformation: \(suggestion.reasoning)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Share Button
                        Button {
                            prepareForSharing()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        // Save Button
                        Button {
                            saveToPhotos()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    Button("Done") {
                        onComplete()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 50)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
        .onAppear { prepareInlineVideoIfNeeded() }
        .onDisappear { cleanupInlineVideo() }
    }
    
    private func prepareForSharing() {
        guard let mediaData = processedMedia.mediaData,
              let image = UIImage(data: mediaData) else { return }
        
        shareImage = image
        showingShareSheet = true
        
        // Update share count
        processedMedia.shareCount += 1
        processedMedia.isShared = true
        
        do {
            try modelContext.save()
        } catch {
            print("Error updating share count: \(error)")
        }
    }
    
    private func saveToPhotos() {
        guard let mediaData = processedMedia.mediaData,
              let image = UIImage(data: mediaData) else { return }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Show success feedback (could add haptic feedback here)
        // For now, just print
        print("Image saved to Photos")
    }
}

// MARK: - Inline Video Helpers
extension ResultView {
    private func prepareInlineVideoIfNeeded() {
        guard processedMedia.isVideo, inlinePlayer == nil, let data = processedMedia.mediaData else { return }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent((processedMedia.fileName.isEmpty == false ? processedMedia.fileName : UUID().uuidString) + ".mp4")
        do {
            try data.write(to: tmp, options: .atomic)
            inlineTempURL = tmp
            let item = AVPlayerItem(url: tmp)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            let looper = AVPlayerLooper(player: queue, templateItem: item)
            inlinePlayer = queue
            inlineLooper = looper
            queue.play()
        } catch {
            print("ResultView: failed to write temp video: \(error)")
        }
    }

    private func cleanupInlineVideo() {
        inlinePlayer?.pause()
        inlinePlayer = nil
        inlineLooper = nil
        if let url = inlineTempURL {
            try? FileManager.default.removeItem(at: url)
            inlineTempURL = nil
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let mockPhoto = Photo(imageData: Data(), originalFileName: "test.jpg")
    let mockSuggestion = TransformationSuggestion(
        photoId: mockPhoto.id,
        type: .creativeTransform,
        title: "Studio Ghibli Style",
        description: "Transform into anime art style",
        reasoning: "Beautiful composition",
        confidence: 0.9,
        falModelId: "test"
    )
    let mockMedia = ProcessedMedia(
        originalPhotoId: mockPhoto.id,
        suggestionId: mockSuggestion.id,
        type: .image,
        fileName: "test.jpg"
    )
    mockMedia.markCompleted(withData: Data())
    
    return ResultView(
        originalPhoto: mockPhoto,
        processedMedia: mockMedia,
        suggestion: mockSuggestion
    ) {
        print("Result view complete")
    }
    .modelContainer(for: Photo.self, inMemory: true)
}
