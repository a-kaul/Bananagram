import Foundation
import SwiftData
import UIKit

@Model
final class Photo {
    var id: UUID
    var imageData: Data
    var originalFileName: String?
    var dateCreated: Date
    var dateModified: Date
    var width: Int
    var height: Int
    var fileSize: Int64
    var isProcessed: Bool
    var analysisCompleted: Bool
    
    @Relationship(deleteRule: .cascade) var analysis: ImageAnalysis?
    @Relationship(deleteRule: .cascade) var suggestions: [TransformationSuggestion]
    @Relationship(deleteRule: .cascade) var processedVersions: [ProcessedMedia]
    
    init(imageData: Data, originalFileName: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.originalFileName = originalFileName
        self.dateCreated = Date()
        self.dateModified = Date()
        self.isProcessed = false
        self.analysisCompleted = false
        self.suggestions = []
        self.processedVersions = []
        
        if let image = UIImage(data: imageData) {
            self.width = Int(image.size.width)
            self.height = Int(image.size.height)
        } else {
            self.width = 0
            self.height = 0
        }
        
        self.fileSize = Int64(imageData.count)
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    var aspectRatio: Double {
        guard height > 0 else { return 1.0 }
        return Double(width) / Double(height)
    }
}