import SwiftUI
import SwiftData

struct MagicStudioView: View {
    let photo: Photo
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var processedItems: [ProcessedMedia]

    @State private var suggestions: [TransformationSuggestion] = []
    @State private var isLoadingSuggestions = true
    @State private var errorMessage: String?

    @State private var activeTasks: Set<UUID> = [] // suggestion.id currently running
    @State private var previews: [UUID: ProcessedMedia] = [:] // suggestion.id -> processed
    @State private var showingDetail: MediaItem?

    init(photo: Photo, onClose: @escaping () -> Void) {
        self.photo = photo
        self.onClose = onClose
        // Avoid SwiftData @Query requiring arguments in init
        self._processedItems = Query(sort: \ProcessedMedia.dateCreated, order: .reverse)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Top: Original Image
                    if let image = photo.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

                    // Suggestions grid or loading
                    if isLoadingSuggestions {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Generating magic filters…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else if let errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Retry") { loadSuggestions() }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(suggestions, id: \.id) { suggestion in
                                SuggestionTile(
                                    photo: photo,
                                    suggestion: suggestion,
                                    isRunning: activeTasks.contains(suggestion.id),
                                    processed: previews[suggestion.id]
                                ) {
                                    runSuggestion(suggestion)
                                } onOpen: { processed in
                                    showingDetail = MediaItem(processedMedia: processed)
                                } onToggleFavorite: { processed in
                                    toggleFavorite(processed)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
                .padding(.top, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Bananagram").font(.headline)
                }
            }
        }
        .onAppear { initialLoad() }
        .fullScreenCover(item: $showingDetail) { item in
            MediaDetailView(item: item) {
                showingDetail = nil
            }
        }
    }

    private func initialLoad() {
        // If we already have suggestions for this photo, use them
        if !photo.suggestions.isEmpty {
            suggestions = photo.suggestions.sorted { $0.orderIndex < $1.orderIndex }
            isLoadingSuggestions = false
            hydratePreviews()
        } else {
            loadSuggestions()
        }
    }

    private func loadSuggestions() {
        isLoadingSuggestions = true
        errorMessage = nil
        Task {
            do {
                let analysis = try await GeminiService.shared.analyzeImage(photo.image ?? UIImage())
                let generated = try await GeminiService.shared.generateTransformationSuggestions(for: analysis)

                var list: [TransformationSuggestion] = []
                for (index, result) in generated.enumerated() {
                    let suggestion = TransformationSuggestion(
                        photoId: photo.id,
                        type: TransformationType(rawValue: result.type) ?? .creativeTransform,
                        title: result.title,
                        description: result.description,
                        reasoning: result.reasoning,
                        confidence: result.confidence,
                        falModelId: result.falModel,
                        orderIndex: index
                    )
                    if let data = try? JSONSerialization.data(withJSONObject: result.parameters), let json = String(data: data, encoding: .utf8) {
                        suggestion.modelParameters = json
                    }
                    list.append(suggestion)
                    modelContext.insert(suggestion)
                    photo.suggestions.append(suggestion)
                }
                try modelContext.save()

                await MainActor.run {
                    suggestions = list
                    isLoadingSuggestions = false
                    hydratePreviews()
                }
            } catch {
                await MainActor.run {
                    isLoadingSuggestions = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func hydratePreviews() {
        var map: [UUID: ProcessedMedia] = [:]
        for s in suggestions {
            if let p = s.processedResult, p.isComplete { map[s.id] = p }
        }
        previews = map
    }

    private func runSuggestion(_ suggestion: TransformationSuggestion) {
        guard !activeTasks.contains(suggestion.id) else { return }
        activeTasks.insert(suggestion.id)

        // Create processed media record up-front
        let mediaType: ProcessedMediaType = suggestion.type == .videoAnimation ? .video : .image
        let fileName = "\(photo.id.uuidString)_\(suggestion.title.lowercased().replacingOccurrences(of: " ", with: "_")).\(mediaType == .video ? "mp4" : "jpg")"
        let media = ProcessedMedia(
            originalPhotoId: photo.id,
            suggestionId: suggestion.id,
            type: mediaType,
            fileName: fileName
        )
        media.status = .processing
        media.falTaskId = UUID().uuidString
        modelContext.insert(media)
        suggestion.processedResult = media
        try? modelContext.save()

        Task {
            do {
                guard let image = photo.image else { throw APIError.invalidImage }
                let params = suggestion.parametersDict
                let result: TransformationResult

                if suggestion.falModelId == "fal-ai/bytedance/video-stylize" {
                    guard let style = params["style"] as? String, !style.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw APIError.invalidResponse
                    }
                    result = try await FALService.shared.stylizeImageToVideo(image, style: style)
                } else {
                    let prompt = params["prompt"] as? String ??
                    "enhance this image as \(suggestion.title.lowercased()): \(suggestion.suggestionDescription)"
                    result = try await FALService.shared.editImage(image, prompt: prompt)
                }

                // Save completed
                media.markCompleted(withData: result.mediaData)
                media.width = Int(image.size.width)
                media.height = Int(image.size.height)
                media.duration = result.duration
                try? modelContext.save()

                await MainActor.run {
                    previews[suggestion.id] = media
                    activeTasks.remove(suggestion.id)
                }
            } catch {
                await MainActor.run {
                    media.markFailed(error: error.localizedDescription)
                    try? modelContext.save()
                    activeTasks.remove(suggestion.id)
                }
            }
        }
    }
    private func toggleFavorite(_ media: ProcessedMedia) {
        media.isFavorited.toggle()
        do { try modelContext.save() } catch { print("MagicStudioView: favorite toggle failed: \(error)") }
    }
}

private struct SuggestionTile: View {
    let photo: Photo
    let suggestion: TransformationSuggestion
    let isRunning: Bool
    let processed: ProcessedMedia?
    let onRun: () -> Void
    let onOpen: (ProcessedMedia) -> Void
    let onToggleFavorite: (ProcessedMedia) -> Void

    var body: some View {
        Button(action: { if processed == nil && !isRunning { onRun() } }) {
            ZStack {
                tileBackground
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                if isRunning { overlayLoading }
            }
        }
        .buttonStyle(.plain)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            alignment: .topLeading,
            content: {
                if let processed, processed.isComplete {
                    header.padding(8)
                }
            }
        )
        .overlay(
            alignment: .bottomTrailing,
            content: {
                if let processed, processed.isComplete {
                    favoriteButton(processed).padding(8)
                }
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.05), lineWidth: 0.5))
    }

    @ViewBuilder private var tileBackground: some View {
        LinearGradient(colors: [Color(.systemGray6), Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder private var content: some View {
        if let processed, processed.isComplete {
            // Show preview
            if processed.isVideo, let data = processed.mediaData {
                LoopingVideoView(data: data, cornerRadius: 0)
                    .onTapGesture { onOpen(processed) }
            } else if let data = processed.mediaData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .onTapGesture { onOpen(processed) }
            } else {
                tileLabel
            }
        } else {
            tileLabel
        }
    }

    private func favoriteButton(_ media: ProcessedMedia) -> some View {
        Button(action: { onToggleFavorite(media) }) {
            Image(systemName: media.isFavorited ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(media.isFavorited ? .red : .white)
                .padding(8)
                .background(Color.black.opacity(0.35), in: Circle())
                .padding(8)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        Text(suggestion.title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(6)
            .background(Color.black.opacity(0.5), in: Capsule())
            .padding(8)
    }

    private var tileLabel: some View {
        VStack(spacing: 8) {
            Image(systemName: suggestion.type == .videoAnimation ? "play.circle.fill" : "wand.and.stars")
                .font(.system(size: 28))
                .foregroundColor(.blue)
            Text(suggestion.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(suggestion.suggestionDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
    }

    private var overlayLoading: some View {
        ZStack {
            Color.black.opacity(0.25)
            ProgressView()
                .tint(.white)
        }
    }
}
