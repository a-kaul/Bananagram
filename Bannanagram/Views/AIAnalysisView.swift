import SwiftUI
import SwiftData

struct AIAnalysisView: View {
    let photo: Photo
    let onComplete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var analysisPhase: AnalysisPhase = .analyzing
    @State private var progress: Double = 0.0
    @State private var suggestions: [TransformationSuggestion] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum AnalysisPhase {
        case analyzing
        case generatingSuggestions
        case completed
        case error
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("AI Analysis")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(phaseDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                Spacer()
                
                // Image Preview
                if let uiImage = photo.image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(16)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Analysis Progress
                VStack(spacing: 20) {
                    switch analysisPhase {
                    case .analyzing, .generatingSuggestions:
                        VStack(spacing: 16) {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 8)
                            
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                
                                Text(progressText)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                    case .completed:
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("Analysis Complete!")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Found \(suggestions.count) magical transformations")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                    case .error:
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            
                            Text("Analysis Failed")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Button
                VStack(spacing: 12) {
                    if analysisPhase == .completed && !suggestions.isEmpty {
                        NavigationLink {
                            SuggestionSelectionView(photo: photo, suggestions: suggestions, onComplete: onComplete)
                        } label: {
                            Text("View Magic Filters")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    } else if analysisPhase == .error {
                        Button("Try Again") {
                            startAnalysis()
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button("Cancel") {
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
        .onAppear {
            startAnalysis()
        }
    }
    
    private var phaseDescription: String {
        switch analysisPhase {
        case .analyzing:
            return "Our AI is analyzing your photo to understand its content, style, and potential..."
        case .generatingSuggestions:
            return "Creating personalized transformation suggestions just for your image..."
        case .completed:
            return "Your magical transformations are ready!"
        case .error:
            return "Something went wrong during analysis"
        }
    }
    
    private var progressText: String {
        switch analysisPhase {
        case .analyzing:
            return "Analyzing image content..."
        case .generatingSuggestions:
            return "Generating magic suggestions..."
        case .completed, .error:
            return ""
        }
    }
    
    private func startAnalysis() {
        analysisPhase = .analyzing
        progress = 0.0
        
        Task {
            do {
                // Check if API is configured
                try APIConfiguration.shared.validateConfiguration()
                
                // Start analysis
                guard let image = photo.image else {
                    throw APIError.invalidImage
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 1.5)) {
                        progress = 0.4
                    }
                }
                
                // Analyze image with Gemini
                let analysisResult = try await GeminiService.shared.analyzeImage(image)
                
                // Create and save analysis
                let analysis = ImageAnalysis(photoId: photo.id, rawResponse: "Gemini analysis completed")
                analysis.detectedObjects = analysisResult.objects
                analysis.sceneDescription = analysisResult.scene
                analysis.lightingConditions = analysisResult.lighting
                analysis.compositionNotes = analysisResult.composition
                analysis.emotionalContext = analysisResult.emotion
                analysis.styleAssessment = analysisResult.style
                analysis.technicalQuality = analysisResult.quality
                analysis.suggestedCategories = analysisResult.improvements
                analysis.confidence = 0.9
                
                modelContext.insert(analysis)
                photo.analysis = analysis
                
                await MainActor.run {
                    analysisPhase = .generatingSuggestions
                    withAnimation(.easeInOut(duration: 1.0)) {
                        progress = 0.7
                    }
                }
                
                // Generate suggestions
                let suggestionResults = try await GeminiService.shared.generateTransformationSuggestions(for: analysisResult)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        progress = 1.0
                    }
                }
                
                // Convert to TransformationSuggestion objects
                var transformationSuggestions: [TransformationSuggestion] = []
                for (index, result) in suggestionResults.enumerated() {
                    if let transformationType = TransformationType(rawValue: result.type) {
                        let suggestion = TransformationSuggestion(
                            photoId: photo.id,
                            type: transformationType,
                            title: result.title,
                            description: result.description,
                            reasoning: result.reasoning,
                            confidence: result.confidence,
                            falModelId: result.falModel,
                            orderIndex: index
                        )
                        
                        suggestion.estimatedProcessingTime = result.processingTime
                        
                        if let paramData = try? JSONSerialization.data(withJSONObject: result.parameters),
                           let paramString = String(data: paramData, encoding: .utf8) {
                            suggestion.modelParameters = paramString
                        }
                        
                        transformationSuggestions.append(suggestion)
                        modelContext.insert(suggestion)
                        photo.suggestions.append(suggestion)
                    }
                }
                
                photo.analysisCompleted = true
                
                try modelContext.save()
                
                await MainActor.run {
                    suggestions = transformationSuggestions
                    analysisPhase = .completed
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    analysisPhase = .error
                }
                
                // Fallback to mock suggestions for demo
                await MainActor.run {
                    generateMockSuggestions()
                }
            }
        }
    }
    
    private func generateMockSuggestions() {
        // Generate mock suggestions using real FAL model IDs
        let mockSuggestions = [
            TransformationSuggestion(
                photoId: photo.id,
                type: .utilityEdit,
                title: "Nano Banana Edit",
                description: "Google's state-of-the-art image editing model for enhanced lighting and quality",
                reasoning: "The image would benefit from professional-grade enhancement and editing",
                confidence: 0.9,
                falModelId: "fal-ai/nano-banana/edit",
                orderIndex: 0
            ),
            TransformationSuggestion(
                photoId: photo.id,
                type: .creativeTransform,
                title: "FLUX Pro Style Transfer",
                description: "Advanced style transfer using cutting-edge AI for artistic transformation",
                reasoning: "The composition and lighting would work beautifully with creative style transformation",
                confidence: 0.85,
                falModelId: "fal-ai/flux-pro/kontext",
                orderIndex: 1
            ),
            TransformationSuggestion(
                photoId: photo.id,
                type: .videoAnimation,
                title: "Decart Lucy Video",
                description: "Create a 5-second video in under 5 seconds with smooth motion",
                reasoning: "The scene has elements that would create beautiful motion and animation",
                confidence: 0.8,
                falModelId: "fal-ai/decart/lucy-5b/image-to-video",
                orderIndex: 2
            ),
            TransformationSuggestion(
                photoId: photo.id,
                type: .utilityEdit,
                title: "Character Edit",
                description: "Modify characters while preserving their core identity and essence",
                reasoning: "Detected characters that could benefit from subtle enhancement",
                confidence: 0.75,
                falModelId: "fal-ai/ideogram/character/edit",
                orderIndex: 3
            ),
            TransformationSuggestion(
                photoId: photo.id,
                type: .videoAnimation,
                title: "Kling Video Master",
                description: "Top-tier image-to-video generation with exceptional motion fluidity",
                reasoning: "The composition would benefit from cinematic motion and video transformation",
                confidence: 0.88,
                falModelId: "fal-ai/kling-video/v2.1/master/image-to-video",
                orderIndex: 4
            )
        ]
        
        suggestions = mockSuggestions
        
        // Save to database
        for suggestion in suggestions {
            modelContext.insert(suggestion)
            photo.suggestions.append(suggestion)
        }
        
        photo.analysisCompleted = true
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving suggestions: \(error)")
            errorMessage = "Failed to save analysis results"
            analysisPhase = .error
        }
    }
}

#Preview {
    let mockPhoto = Photo(imageData: Data(), originalFileName: "test.jpg")
    
    return AIAnalysisView(photo: mockPhoto) {
        print("Analysis complete")
    }
    .modelContainer(for: Photo.self, inMemory: true)
}