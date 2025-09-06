import Foundation
import UIKit

class FALService: ObservableObject {
    static let shared = FALService()
    
    private let baseURL = "https://fal.run/fal-ai"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Image Transformation
    
    func transformImage(
        _ image: UIImage,
        modelId: String,
        parameters: [String: Any]
    ) async throws -> TransformationResult {
        guard let apiKey = try? APIConfiguration.shared.falAIAPIKey else {
            throw APIError.missingAPIKey("FAL AI API key not configured")
        }
        
        // First, upload the image
        let imageURL = try await uploadImage(image, apiKey: apiKey)
        
        // Then, start the transformation
        let taskId = try await startTransformation(
            imageURL: imageURL,
            modelId: modelId,
            parameters: parameters,
            apiKey: apiKey
        )
        
        // Poll for completion
        return try await pollTransformation(taskId: taskId, apiKey: apiKey)
    }
    
    // MARK: - Video Generation
    
    func generateVideo(
        from image: UIImage,
        modelId: String,
        parameters: [String: Any]
    ) async throws -> TransformationResult {
        guard let apiKey = try? APIConfiguration.shared.falAIAPIKey else {
            throw APIError.missingAPIKey("FAL AI API key not configured")
        }
        
        // Upload image
        let imageURL = try await uploadImage(image, apiKey: apiKey)
        
        // Start video generation
        let taskId = try await startVideoGeneration(
            imageURL: imageURL,
            modelId: modelId,
            parameters: parameters,
            apiKey: apiKey
        )
        
        // Poll for completion (videos take longer)
        return try await pollTransformation(taskId: taskId, apiKey: apiKey, isVideo: true)
    }
    
    // MARK: - Upload Image
    
    private func uploadImage(_ image: UIImage, apiKey: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw APIError.invalidImage
        }
        
        let url = URL(string: "\(baseURL)/storage/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.apiError("Failed to upload image")
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.url
    }
    
    // MARK: - Start Transformation
    
    private func startTransformation(
        imageURL: String,
        modelId: String,
        parameters: [String: Any],
        apiKey: String
    ) async throws -> String {
        var transformParams = parameters
        transformParams["image_url"] = imageURL
        
        let url = URL(string: "\(baseURL)/\(modelId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "input": transformParams
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.apiError("Failed to start transformation")
        }
        
        let taskResponse = try JSONDecoder().decode(TaskResponse.self, from: data)
        return taskResponse.request_id
    }
    
    // MARK: - Start Video Generation
    
    private func startVideoGeneration(
        imageURL: String,
        modelId: String,
        parameters: [String: Any],
        apiKey: String
    ) async throws -> String {
        var videoParams = parameters
        videoParams["image_url"] = imageURL
        videoParams["motion_strength"] = videoParams["motion_strength"] ?? 127
        videoParams["fps"] = videoParams["fps"] ?? 16
        videoParams["duration"] = videoParams["duration"] ?? 3.0
        
        return try await startTransformation(
            imageURL: imageURL,
            modelId: modelId,
            parameters: videoParams,
            apiKey: apiKey
        )
    }
    
    // MARK: - Poll for Completion
    
    private func pollTransformation(
        taskId: String,
        apiKey: String,
        isVideo: Bool = false
    ) async throws -> TransformationResult {
        let maxAttempts = isVideo ? 60 : 30 // Videos can take up to 5 minutes
        let pollInterval: TimeInterval = isVideo ? 5.0 : 2.0
        
        for attempt in 0..<maxAttempts {
            let url = URL(string: "\(baseURL)/\(taskId)/status")!
            var request = URLRequest(url: url)
            request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw APIError.apiError("Failed to check transformation status")
            }
            
            let statusResponse = try JSONDecoder().decode(StatusResponse.self, from: data)
            
            switch statusResponse.status {
            case "completed":
                return try parseCompletedResult(statusResponse, isVideo: isVideo)
            case "failed":
                throw APIError.apiError(statusResponse.error ?? "Transformation failed")
            case "in_progress", "queued":
                // Continue polling
                try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                continue
            default:
                throw APIError.apiError("Unknown status: \(statusResponse.status)")
            }
        }
        
        throw APIError.apiError("Transformation timed out")
    }
    
    // MARK: - Result Parsing
    
    private func parseCompletedResult(_ response: StatusResponse, isVideo: Bool) throws -> TransformationResult {
        guard let output = response.output else {
            throw APIError.invalidResponse
        }
        
        let mediaURL: String
        if isVideo {
            mediaURL = output["video"] as? String ?? output["url"] as? String ?? ""
        } else {
            mediaURL = output["image"] as? String ?? output["url"] as? String ?? ""
        }
        
        guard !mediaURL.isEmpty else {
            throw APIError.invalidResponse
        }
        
        // Download the result
        let mediaData = try await downloadMedia(from: mediaURL)
        
        return TransformationResult(
            mediaData: mediaData,
            isVideo: isVideo,
            duration: isVideo ? (output["duration"] as? TimeInterval) : nil,
            metadata: output
        )
    }
    
    // MARK: - Download Media
    
    private func downloadMedia(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw APIError.apiError("Invalid media URL")
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.apiError("Failed to download media")
        }
        
        return data
    }
    
    // MARK: - Available Models
    
    func getAvailableModels() -> [FALModel] {
        return [
            // Image Enhancement Models
            FALModel(
                id: "enhance/lighting",
                name: "Enhance Lighting",
                type: .utilityEdit,
                description: "Improve lighting and exposure",
                estimatedTime: 5.0
            ),
            FALModel(
                id: "enhance/upscale",
                name: "Super Resolution",
                type: .utilityEdit,
                description: "Increase image resolution and sharpness",
                estimatedTime: 8.0
            ),
            FALModel(
                id: "enhance/denoise",
                name: "Noise Reduction",
                type: .utilityEdit,
                description: "Remove noise and grain",
                estimatedTime: 6.0
            ),
            
            // Creative Transform Models
            FALModel(
                id: "style/anime",
                name: "Anime Style",
                type: .creativeTransform,
                description: "Transform to anime art style",
                estimatedTime: 15.0
            ),
            FALModel(
                id: "style/vintage",
                name: "Vintage Film",
                type: .creativeTransform,
                description: "Apply vintage film aesthetics",
                estimatedTime: 12.0
            ),
            FALModel(
                id: "style/oil-painting",
                name: "Oil Painting",
                type: .creativeTransform,
                description: "Convert to oil painting style",
                estimatedTime: 18.0
            ),
            
            // Video Animation Models
            FALModel(
                id: "video/cinemagraph",
                name: "Cinemagraph",
                type: .videoAnimation,
                description: "Create subtle motion loop",
                estimatedTime: 45.0
            ),
            FALModel(
                id: "video/parallax",
                name: "Parallax Effect",
                type: .videoAnimation,
                description: "Add depth-based motion",
                estimatedTime: 35.0
            ),
            FALModel(
                id: "video/morph",
                name: "Style Morph",
                type: .videoAnimation,
                description: "Animated style transformation",
                estimatedTime: 60.0
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

// MARK: - API Response Models

struct UploadResponse: Codable {
    let url: String
}

struct TaskResponse: Codable {
    let request_id: String
}

struct StatusResponse: Codable {
    let status: String
    let output: [String: Any]?
    let error: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        
        // Handle dynamic output object
        if let outputContainer = try? container.nestedContainer(keyedBy: DynamicKey.self, forKey: .output) {
            var outputDict: [String: Any] = [:]
            for key in outputContainer.allKeys {
                if let value = try? outputContainer.decode(String.self, forKey: key) {
                    outputDict[key.stringValue] = value
                } else if let value = try? outputContainer.decode(Double.self, forKey: key) {
                    outputDict[key.stringValue] = value
                } else if let value = try? outputContainer.decode(Bool.self, forKey: key) {
                    outputDict[key.stringValue] = value
                }
            }
            output = outputDict.isEmpty ? nil : outputDict
        } else {
            output = nil
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case status, output, error
    }
}

struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}