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
    
    // Observe the FAL service for real-time updates
    private let falService = FALService.shared
    
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
                        Text(falService.isProcessing && !falService.processingStatus.isEmpty ? falService.processingStatus : processingPhase.title)
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
                            ProgressView(value: falService.isProcessing ? falService.processingProgress : progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 8)
                                .animation(.easeInOut(duration: 0.3), value: falService.isProcessing ? falService.processingProgress : progress)
                            
                            HStack {
                                Text("\(Int((falService.isProcessing ? falService.processingProgress : progress) * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                let currentProgress = falService.isProcessing ? falService.processingProgress : progress
                                let remainingTime = suggestion.estimatedProcessingTime * (1 - currentProgress)
                                Text("~\(Int(max(0, remainingTime)))s remaining")
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
            print("🎬 ProcessingView: Starting processing for suggestion: \(suggestion.title)")
            print("🔧 ProcessingView: Suggestion FAL Model ID: \(suggestion.falModelId)")
            
            // Check API configuration
            try APIConfiguration.shared.validateConfiguration()
            
            guard let image = photo.image else {
                print("❌ ProcessingView: No image available for processing")
                throw APIError.invalidImage
            }
            
            print("✅ ProcessingView: Image available for processing")
            
            // We're now using nano-banana for all transformations
            print("✅ ProcessingView: Using nano-banana model for all transformations")
            print("🎯 ProcessingView: Suggestion model: \(suggestion.falModelId)")
            
            await MainActor.run {
                processingPhase = .transforming
            }
            
            // Get the prompt from parameters or use suggestion title as prompt
            let parameters = suggestion.parametersDict
            let prompt = parameters["prompt"] as? String ?? 
                        "enhance this image as \(suggestion.title.lowercased()): \(suggestion.suggestionDescription)"
            
            print("🔧 ProcessingView: Using prompt: \(prompt)")
            
            // Use the new simplified FAL service
            print("🚀 ProcessingView: Calling FALService.editImage...")
            let result = try await FALService.shared.editImage(
                image,
                prompt: prompt
            )
            
            print("✅ ProcessingView: Transform completed!")
            print("📊 ProcessingView: Result metadata: \(result.metadata)")
            
            if let isMock = result.metadata["mock"] as? Bool, isMock {
                print("⚠️ ProcessingView: RESULT IS MOCK - Original image returned")
            } else {
                print("🎉 ProcessingView: REAL transformation completed!")
            }
            
            await MainActor.run {
                processingPhase = .finalizing
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
    
    return ProcessingView(photo: mockPhoto, suggestion: mockSuggestion) {
        print("Processing complete")
    }
    .modelContainer(for: Photo.self, inMemory: true)
}