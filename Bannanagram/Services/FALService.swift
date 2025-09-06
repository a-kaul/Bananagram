import Foundation
import UIKit
import FalClient

@Observable
class FALService {
    static let shared = FALService()
    
    private var falClient: (any Client)?
    var isProcessing = false
    var processingProgress: Double = 0.0
    var processingStatus = ""
    
    private init() {
        setupClient()
    }
    
    private func setupClient() {
        print("🔍 FALService: Setting up FAL client...")
        
        do {
            let apiKey = try APIConfiguration.shared.falAIAPIKey
            print("✅ FALService: API key retrieved successfully")
            falClient = FalClient.withCredentials(.keyPair(apiKey))
            print("✅ FALService: Client setup complete")
        } catch {
            print("❌ FALService: Client setup failed - \(error)")
            falClient = nil
        }
    }
    
    // MARK: - Unified Transformation Method
    
    func transform(
        _ image: UIImage,
        using model: FALModel,
        parameters: [String: Any] = [:]
    ) async throws -> TransformationResult {
        // For now, return a mock result until we fix the fal.ai integration
        // This allows the app to build and function while we work on the API
        
        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
            processingStatus = "Starting transformation..."
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0.0
                processingStatus = ""
            }
        }
        
        // Convert image to JPEG data for mock result
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw APIError.invalidImage
        }
        
        await MainActor.run {
            processingStatus = "Processing with \(model.name)..."
        }
        
        // Simulate processing time
        for i in 1...10 {
            await MainActor.run {
                processingProgress = Double(i) / 10.0
            }
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        await MainActor.run {
            processingStatus = "Finalizing..."
            processingProgress = 1.0
        }
        
        // Return mock result with original image
        return TransformationResult(
            mediaData: imageData,
            isVideo: model.type == .videoAnimation,
            duration: model.type == .videoAnimation ? 3.0 : nil,
            metadata: ["mock": true, "model": model.id]
        )
    }
    
    
    // MARK: - Available Models
    
    func getAvailableModels() -> [FALModel] {
        return [
            // Image Enhancement/Edit Models
            FALModel(
                id: "fal-ai/nano-banana/edit",
                name: "Nano Banana Edit",
                type: .utilityEdit,
                description: "Google's state-of-the-art image editing model",
                estimatedTime: 8.0
            ),
            FALModel(
                id: "fal-ai/flux/krea/image-to-image",
                name: "FLUX Krea Enhancement",
                type: .utilityEdit,
                description: "High-quality image enhancement and editing",
                estimatedTime: 12.0
            ),
            FALModel(
                id: "fal-ai/ideogram/character/edit",
                name: "Character Edit",
                type: .utilityEdit,
                description: "Modify characters while preserving identity",
                estimatedTime: 10.0
            ),
            
            // Creative Transform Models
            FALModel(
                id: "fal-ai/flux-pro/kontext",
                name: "FLUX Pro Style Transfer",
                type: .creativeTransform,
                description: "Advanced style transfer using reference images",
                estimatedTime: 15.0
            ),
            FALModel(
                id: "fal-ai/uso",
                name: "USO Style Generation",
                type: .creativeTransform,
                description: "Subject-driven style transformations",
                estimatedTime: 18.0
            ),
            
            // Video Animation Models
            FALModel(
                id: "fal-ai/kling-video/v2.1/master/image-to-video",
                name: "Kling Video Master",
                type: .videoAnimation,
                description: "Top-tier image-to-video with motion fluidity",
                estimatedTime: 45.0
            ),
            FALModel(
                id: "moonvalley/marey/i2v",
                name: "Marey Realism Video",
                type: .videoAnimation,
                description: "Realistic video generation from images",
                estimatedTime: 40.0
            ),
            FALModel(
                id: "fal-ai/minimax/hailuo-02/standard/image-to-video",
                name: "MiniMax Hailuo Video",
                type: .videoAnimation,
                description: "Advanced image-to-video generation",
                estimatedTime: 50.0
            ),
            FALModel(
                id: "fal-ai/veo3/fast/image-to-video",
                name: "Veo 3 Fast Video",
                type: .videoAnimation,
                description: "Fast video generation from images",
                estimatedTime: 35.0
            ),
            FALModel(
                id: "fal-ai/decart/lucy-5b/image-to-video",
                name: "Decart Lucy Video",
                type: .videoAnimation,
                description: "5-second videos generated in under 5 seconds",
                estimatedTime: 8.0
            )
        ]
    }
}

// MARK: - Data Models

struct TransformationResult {
    let mediaData: Data
    let isVideo: Bool
    let duration: TimeInterval?
    let metadata: [String: Any]
}

struct FALModel {
    let id: String
    let name: String
    let type: TransformationType
    let description: String
    let estimatedTime: TimeInterval
}