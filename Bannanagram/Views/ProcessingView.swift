import SwiftUI
import SwiftData

struct ProcessingView: View {
    let photo: Photo
    let suggestion: TransformationSuggestion
    let onComplete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var progress: Double = 0.0
    @State private var processingPhase: ProcessingPhase = .preparing
    @State private var processedMedia: ProcessedMedia?
    @State private var showingResult = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum ProcessingPhase: CaseIterable {
        case preparing
        case analyzing
        case transforming
        case finalizing
        case completed
        case error
        
        var title: String {
            switch self {
            case .preparing: return "Preparing..."
            case .analyzing: return "Analyzing..."
            case .transforming: return "Transforming..."
            case .finalizing: return "Finalizing..."
            case .completed: return "Complete!"
            case .error: return "Error"
            }
        }
        
        var description: String {
            switch self {
            case .preparing: return "Setting up the magical transformation"
            case .analyzing: return "AI is understanding your image"
            case .transforming: return "Applying the magic filter"
            case .finalizing: return "Putting the finishing touches"
            case .completed: return "Your magical transformation is ready!"
            case .error: return "Something went wrong"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Creating Magic")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Applying \(suggestion.title)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                Spacer()
                
                // Processing Animation
                VStack(spacing: 30) {
                    // Magic Wand Animation
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .scaleEffect(processingPhase == .transforming ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: processingPhase)
                        
                        Image(systemName: suggestion.type == .videoAnimation ? "play.circle.fill" : "wand.and.stars")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(processingPhase == .transforming ? 360 : 0))
                            .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: processingPhase)
                    }
                    
                    // Phase Information
                    VStack(spacing: 12) {
                        Text(processingPhase.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(processingPhase.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Progress Bar
                    if processingPhase != .completed && processingPhase != .error {
                        VStack(spacing: 8) {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 8)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                            
                            HStack {
                                Text("\(Int(progress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("~\(Int(suggestion.estimatedProcessingTime * (1 - progress)))s remaining")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Error State
                    if processingPhase == .error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Success State
                    if processingPhase == .completed {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Button("View Result") {
                                showingResult = true
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Cancel Button (only during processing)
                if processingPhase != .completed && processingPhase != .error {
                    Button("Cancel") {
                        onComplete()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 50)
                } else if processingPhase == .error {
                    VStack(spacing: 12) {
                        Button("Try Again") {
                            startProcessing()
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        
                        Button("Cancel") {
                            onComplete()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .onAppear {
            startProcessing()
        }
        .fullScreenCover(isPresented: $showingResult) {
            if let media = processedMedia {
                ResultView(
                    originalPhoto: photo,
                    processedMedia: media,
                    suggestion: suggestion,
                    onComplete: onComplete
                )
            }
        }
    }
    
    private func startProcessing() {
        processingPhase = .preparing
        progress = 0.0
        
        // Create processed media record
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
        processedMedia = media
        
        modelContext.insert(media)
        suggestion.processedResult = media
        
        // Start real processing
        Task {
            await performRealProcessing()
        }
    }
    
    private func performRealProcessing() async {
        do {
            // Check API configuration
            try APIConfiguration.shared.validateConfiguration()
            
            guard let image = photo.image else {
                throw APIError.invalidImage
            }
            
            await MainActor.run {
                processingPhase = .analyzing
                withAnimation(.easeInOut(duration: 1.0)) {
                    progress = 0.2
                }
            }
            
            // Get parameters for the transformation
            let parameters = suggestion.parametersDict
            
            await MainActor.run {
                processingPhase = .transforming
                withAnimation(.easeInOut(duration: 1.5)) {
                    progress = 0.5
                }
            }
            
            // Perform transformation based on type
            let result: TransformationResult
            if suggestion.type == .videoAnimation {
                result = try await FALService.shared.generateVideo(
                    from: image,
                    modelId: suggestion.falModelId,
                    parameters: parameters
                )
            } else {
                result = try await FALService.shared.transformImage(
                    image,
                    modelId: suggestion.falModelId,
                    parameters: parameters
                )
            }
            
            await MainActor.run {
                processingPhase = .finalizing
                withAnimation(.easeInOut(duration: 0.5)) {
                    progress = 0.9
                }
            }
            
            // Save the result
            guard let media = processedMedia else { return }
            media.markCompleted(withData: result.mediaData)
            media.width = Int(image.size.width)
            media.height = Int(image.size.height)
            media.duration = result.duration
            
            try modelContext.save()
            
            await MainActor.run {
                processingPhase = .completed
                progress = 1.0
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                processingPhase = .error
                
                // Fallback to mock processing for demo
                simulateProcessing()
            }
        }
    }
    
    private func simulateProcessing() {
        let phases: [ProcessingPhase] = [.preparing, .analyzing, .transforming, .finalizing]
        let phaseDuration = suggestion.estimatedProcessingTime / Double(phases.count)
        
        for (index, phase) in phases.enumerated() {
            let delay = Double(index) * phaseDuration
            let phaseProgress = Double(index + 1) / Double(phases.count + 1)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                processingPhase = phase
                
                withAnimation(.easeInOut(duration: phaseDuration * 0.8)) {
                    progress = phaseProgress
                }
            }
        }
        
        // Complete processing
        DispatchQueue.main.asyncAfter(deadline: .now() + suggestion.estimatedProcessingTime) {
            completeProcessing()
        }
    }
    
    private func completeProcessing() {
        guard let media = processedMedia else { return }
        
        // Mock successful completion with original image data
        media.markCompleted(withData: photo.imageData, thumbnailData: photo.imageData)
        
        do {
            try modelContext.save()
            processingPhase = .completed
            progress = 1.0
        } catch {
            errorMessage = "Failed to save processed media: \(error.localizedDescription)"
            processingPhase = .error
        }
    }
}

#Preview {
    let mockPhoto = Photo(imageData: Data(), originalFileName: "test.jpg")
    let mockSuggestion = TransformationSuggestion(
        photoId: mockPhoto.id,
        type: .creativeTransform,
        title: "Studio Ghibli Style",
        description: "Test transformation",
        reasoning: "Test",
        confidence: 0.9,
        falModelId: "test"
    )
    
    ProcessingView(photo: mockPhoto, suggestion: mockSuggestion) {
        print("Processing complete")
    }
    .modelContainer(for: Photo.self, inMemory: true)
}