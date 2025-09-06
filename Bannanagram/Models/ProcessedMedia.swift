import Foundation
import SwiftData

enum ProcessedMediaType: String, Codable {
    case image = "image"
    case video = "video"
}

enum ProcessingStatus: String, Codable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

@Model
final class ProcessedMedia {
    var id: UUID
    var originalPhotoId: UUID
    var suggestionId: UUID?
    var type: ProcessedMediaType
    var status: ProcessingStatus
    var mediaData: Data?
    var thumbnailData: Data?
    var fileName: String
    var fileSize: Int64
    var width: Int?
    var height: Int?
    var duration: TimeInterval? // For videos
    var processingProgress: Double
    var processingError: String?
    var falTaskId: String?
    var dateCreated: Date
    var dateCompleted: Date?
    var shareURL: String?
    var isShared: Bool
    var shareCount: Int
    
    @Relationship(inverse: \Photo.processedVersions) var originalPhoto: Photo?
    @Relationship(inverse: \TransformationSuggestion.processedResult) var suggestion: TransformationSuggestion?
    
    init(
        originalPhotoId: UUID,
        suggestionId: UUID? = nil,
        type: ProcessedMediaType,
        fileName: String
    ) {
        self.id = UUID()
        self.originalPhotoId = originalPhotoId
        self.suggestionId = suggestionId
        self.type = type
        self.status = .pending
        self.fileName = fileName
        self.fileSize = 0
        self.processingProgress = 0.0
        self.dateCreated = Date()
        self.isShared = false
        self.shareCount = 0
    }
    
    var isVideo: Bool {
        type == .video
    }
    
    var isComplete: Bool {
        status == .completed && mediaData != nil
    }
    
    var hasError: Bool {
        status == .failed
    }
    
    func updateProgress(_ progress: Double) {
        self.processingProgress = min(1.0, max(0.0, progress))
        
        if progress >= 1.0 && status == .processing {
            self.status = .completed
            self.dateCompleted = Date()
        }
    }
    
    func markFailed(error: String) {
        self.status = .failed
        self.processingError = error
        self.dateCompleted = Date()
    }
    
    func markCompleted(withData data: Data, thumbnailData: Data? = nil) {
        self.mediaData = data
        self.thumbnailData = thumbnailData
        self.fileSize = Int64(data.count)
        self.status = .completed
        self.dateCompleted = Date()
        self.processingProgress = 1.0
    }
}