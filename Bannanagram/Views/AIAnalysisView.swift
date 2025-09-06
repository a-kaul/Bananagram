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
        // Generate mock suggestions for now
        let mockSuggestions = [
            TransformationSuggestion(
                photoId: photo.id,
                type: .utilityEdit,
                title: "Enhance Lighting",
                description: "Brighten shadows and balance exposure for a more professional look",
                reasoning: "The image has some dark areas that could benefit from lighting enhancement",
                confidence: 0.9,
                falModelId: "enhance-lighting-v1",
                orderIndex: 0
            ),
            TransformationSuggestion(
                photoId: photo.id,
                type: .creativeTransform,
                title: "Studio Ghibli Style",
                description: "Transform into a dreamy anime art style reminiscent of Studio Ghibli films",
                reasoning: "The composition and natural elements would work beautifully in anime style",
                confidence: 0.85,
                falModelId: "anime-style-v2",
                orderIndex: 1
            ),
            TransformationSuggestion(
                photoId: photo.id,
                type: .videoAnimation,
                title: "Cinemagraph Loop",
                description: "Create a subtle animated loop with moving elements while keeping the main subject still",
                reasoning: "There are elements in the scene that would create a beautiful cinemagraph effect",
                confidence: 0.8,
                falModelId: "cinemagraph-v1",
                orderIndex: 2
            ),
            TransformationSuggestion(
                photoId: photo.id,
                type: .creativeTransform,
                title: "Vintage Film Look",
                description: "Apply classic 35mm film aesthetics with warm tones and subtle grain",
                reasoning: "The lighting and composition would benefit from vintage film treatment",
                confidence: 0.75,
                falModelId: "vintage-film-v1",
                orderIndex: 3
            ),
            TransformationSuggestion(
                photoId: photo.id,
                type: .utilityEdit,
                title: "Portrait Enhancement",
                description: "Subtle skin smoothing and eye enhancement while maintaining natural appearance",
                reasoning: "Detected facial features that could benefit from portrait optimization",
                confidence: 0.88,
                falModelId: "portrait-enhance-v1",
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
    
    AIAnalysisView(photo: mockPhoto) {
        print("Analysis complete")
    }
    .modelContainer(for: Photo.self, inMemory: true)
}