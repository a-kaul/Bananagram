import Foundation
import SwiftData

enum TransformationType: String, Codable, CaseIterable {
    case utilityEdit = "utility_edit"
    case creativeTransform = "creative_transform"
    case videoAnimation = "video_animation"
    
    var displayName: String {
        switch self {
        case .utilityEdit:
            return "Utility Edit"
        case .creativeTransform:
            return "Creative Transform"
        case .videoAnimation:
            return "Video Animation"
        }
    }
}

@Model
final class TransformationSuggestion {
    var id: UUID
    var photoId: UUID
    var type: TransformationType
    var title: String
    var suggestionDescription: String
    var reasoning: String
    var confidence: Double
    var estimatedProcessingTime: TimeInterval
    var falModelId: String
    var modelParameters: String // JSON string of parameters
    var previewPrompt: String
    var dateCreated: Date
    var isSelected: Bool
    var orderIndex: Int
    
    @Relationship(inverse: \Photo.suggestions) var photo: Photo?
    @Relationship(deleteRule: .cascade) var processedResult: ProcessedMedia?
    
    init(
        photoId: UUID,
        type: TransformationType,
        title: String,
        description: String,
        reasoning: String,
        confidence: Double,
        falModelId: String,
        modelParameters: String = "{}",
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.photoId = photoId
        self.type = type
        self.title = title
        self.suggestionDescription = description
        self.reasoning = reasoning
        self.confidence = confidence
        self.falModelId = falModelId
        self.modelParameters = modelParameters
        self.previewPrompt = title
        self.dateCreated = Date()
        self.isSelected = false
        self.orderIndex = orderIndex
        
        // Estimate processing time based on type
        switch type {
        case .utilityEdit:
            self.estimatedProcessingTime = 5.0 // 5 seconds
        case .creativeTransform:
            self.estimatedProcessingTime = 15.0 // 15 seconds
        case .videoAnimation:
            self.estimatedProcessingTime = 45.0 // 45 seconds
        }
    }
    
    var parametersDict: [String: Any] {
        guard let data = modelParameters.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    func updateParameters(_ parameters: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: parameters),
           let jsonString = String(data: data, encoding: .utf8) {
            self.modelParameters = jsonString
        }
    }
}