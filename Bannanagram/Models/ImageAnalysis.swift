import Foundation
import SwiftData

@Model
final class ImageAnalysis {
    var id: UUID
    var photoId: UUID
    var dateAnalyzed: Date
    var rawResponse: String
    var detectedObjects: [String]
    var sceneDescription: String
    var lightingConditions: String
    var compositionNotes: String
    var emotionalContext: String
    var styleAssessment: String
    var technicalQuality: String
    var suggestedCategories: [String]
    var confidence: Double
    
    @Relationship(inverse: \Photo.analysis) var photo: Photo?
    
    init(photoId: UUID, rawResponse: String) {
        self.id = UUID()
        self.photoId = photoId
        self.dateAnalyzed = Date()
        self.rawResponse = rawResponse
        self.detectedObjects = []
        self.sceneDescription = ""
        self.lightingConditions = ""
        self.compositionNotes = ""
        self.emotionalContext = ""
        self.styleAssessment = ""
        self.technicalQuality = ""
        self.suggestedCategories = []
        self.confidence = 0.0
        
        parseResponse(rawResponse)
    }
    
    private func parseResponse(_ response: String) {
        // TODO: Implement parsing logic for Gemini API response
        // This will extract structured data from the LLM response
    }
}