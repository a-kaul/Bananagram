import Foundation
import UIKit

@Observable
class GeminiService {
    static let shared = GeminiService()
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Image Analysis
    
    func analyzeImage(_ image: UIImage) async throws -> ImageAnalysisResult {
        print("🔍 GeminiService: Starting image analysis...")
        
        do {
            let apiKey = try APIConfiguration.shared.geminiAPIKey
            print("✅ GeminiService: API key retrieved successfully")
        } catch {
            print("❌ GeminiService: Failed to get API key - \(error)")
            throw APIError.missingAPIKey("Gemini API key not configured")
        }
        
        let apiKey = try APIConfiguration.shared.geminiAPIKey
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let prompt = """
        Analyze this image and provide detailed insights for AI-powered photo transformation suggestions. 
        
        Please analyze:
        1. Objects and subjects in the image
        2. Scene type and setting
        3. Lighting conditions and quality
        4. Composition and framing
        5. Emotional context or mood
        6. Current style/aesthetic
        7. Technical quality assessment
        8. Potential areas for improvement
        
        Respond in JSON format with the following structure:
        {
            "objects": ["list", "of", "detected", "objects"],
            "scene": "description of the scene",
            "lighting": "lighting conditions assessment",
            "composition": "composition analysis",
            "emotion": "emotional context",
            "style": "current style assessment", 
            "quality": "technical quality notes",
            "improvements": ["potential", "improvement", "areas"]
        }
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 1024
            ]
        ]
        
        let url = URL(string: "\(baseURL)/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.apiError("Failed to analyze image")
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let content = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw APIError.invalidResponse
        }
        
        return try parseAnalysisResponse(content)
    }
    
    // MARK: - Suggestion Generation
    
    func generateTransformationSuggestions(for analysis: ImageAnalysisResult) async throws -> [SuggestionResult] {
        guard let apiKey = try? APIConfiguration.shared.geminiAPIKey else {
            throw APIError.missingAPIKey("Gemini API key not configured")
        }
        
        let prompt = """
        Based on this image analysis, generate exactly 5 personalized transformation suggestions that would create magical, Instagram-filter-like effects.
        
        Image Analysis:
        - Objects: \(analysis.objects.joined(separator: ", "))
        - Scene: \(analysis.scene)
        - Lighting: \(analysis.lighting)
        - Composition: \(analysis.composition)
        - Emotion: \(analysis.emotion)
        - Style: \(analysis.style)
        - Quality: \(analysis.quality)
        - Improvements: \(analysis.improvements.joined(separator: ", "))
        
        Generate suggestions in these categories:
        1. Utility Edit (practical improvements like lighting, exposure, noise reduction)
        2. Creative Transform (artistic styles like anime, vintage, pop art)
        3. Video Animation (subtle motion effects, cinemagraphs)
        
        Additional instruction for Video Animation:
        - You may include at most ONE (1) suggestion that converts the image into a short animated video using fal.ai’s image-to-video stylization model.
        - When you include this, use: "fal_model": "fal-ai/bytedance/video-stylize"
        - Provide a single, simple style name in parameters under the key "style" (e.g., "Manga style", "Watercolor", "Cyberpunk neon"). Keep the style concise. Do NOT add complex parameter sets.
        
        Each suggestion should be highly relevant to the specific image content and feel personalized.
        
        Respond in JSON format:
        {
            "suggestions": [
                {
                    "type": "utility_edit|creative_transform|video_animation",
                    "title": "Short descriptive title",
                    "description": "Detailed explanation of the transformation",
                    "reasoning": "Why this suggestion fits this specific image",
                    "confidence": 0.0-1.0,
                    "fal_model": "suggested_model_name",
                    "parameters": {"key": "value"},
                    "processing_time": estimated_seconds
                }
            ]
        }
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.8,
                "maxOutputTokens": 2048
            ]
        ]
        
        let url = URL(string: "\(baseURL)/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.apiError("Failed to generate suggestions")
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let content = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw APIError.invalidResponse
        }
        
        let suggestions = try parseSuggestionsResponse(content)

        // Enforce at most one bytedance video-stylize suggestion client-side
        var seenVideoStylize = false
        let filtered = suggestions.filter { s in
            if s.falModel == "fal-ai/bytedance/video-stylize" {
                if seenVideoStylize { return false }
                seenVideoStylize = true
                return true
            }
            return true
        }

        return filtered
    }
    
    // MARK: - Response Parsing
    
    private func parseAnalysisResponse(_ content: String) throws -> ImageAnalysisResult {
        // Extract JSON from the response (may have markdown formatting)
        let jsonStart = content.range(of: "{")
        let jsonEnd = content.range(of: "}", options: .backwards)
        
        guard let start = jsonStart?.lowerBound,
              let end = jsonEnd?.upperBound else {
            throw APIError.invalidResponse
        }
        
        let jsonString = String(content[start..<end])
        let jsonData = jsonString.data(using: .utf8)!
        
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        return ImageAnalysisResult(
            objects: parsed["objects"] as? [String] ?? [],
            scene: parsed["scene"] as? String ?? "",
            lighting: parsed["lighting"] as? String ?? "",
            composition: parsed["composition"] as? String ?? "",
            emotion: parsed["emotion"] as? String ?? "",
            style: parsed["style"] as? String ?? "",
            quality: parsed["quality"] as? String ?? "",
            improvements: parsed["improvements"] as? [String] ?? []
        )
    }
    
    private func parseSuggestionsResponse(_ content: String) throws -> [SuggestionResult] {
        // Extract JSON from the response (may have markdown formatting)
        let jsonStart = content.range(of: "{")
        let jsonEnd = content.range(of: "}", options: .backwards)
        
        guard let start = jsonStart?.lowerBound,
              let end = jsonEnd?.upperBound else {
            throw APIError.invalidResponse
        }
        
        let jsonString = String(content[start..<end])
        let jsonData = jsonString.data(using: .utf8)!
        
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let suggestionsArray = parsed["suggestions"] as! [[String: Any]]
        
        return suggestionsArray.compactMap { dict in
            guard let type = dict["type"] as? String,
                  let title = dict["title"] as? String,
                  let description = dict["description"] as? String,
                  let reasoning = dict["reasoning"] as? String,
                  let confidence = dict["confidence"] as? Double,
                  let falModel = dict["fal_model"] as? String else {
                return nil
            }
            
            let parameters = dict["parameters"] as? [String: Any] ?? [:]
            let processingTime = dict["processing_time"] as? TimeInterval ?? 15.0
            
            return SuggestionResult(
                type: type,
                title: title,
                description: description,
                reasoning: reasoning,
                confidence: confidence,
                falModel: falModel,
                parameters: parameters,
                processingTime: processingTime
            )
        }
    }
}

// MARK: - Data Models

struct ImageAnalysisResult {
    let objects: [String]
    let scene: String
    let lighting: String
    let composition: String
    let emotion: String
    let style: String
    let quality: String
    let improvements: [String]
}

struct SuggestionResult {
    let type: String
    let title: String
    let description: String
    let reasoning: String
    let confidence: Double
    let falModel: String
    let parameters: [String: Any]
    let processingTime: TimeInterval
}

// MARK: - API Response Models

struct GeminiResponse: Codable {
    let candidates: [Candidate]
}

struct Candidate: Codable {
    let content: Content
}

struct Content: Codable {
    let parts: [Part]
}

struct Part: Codable {
    let text: String
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case missingAPIKey(String)
    case invalidImage
    case apiError(String)
    case invalidResponse
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let key):
            return "Missing API key: \(key)"
        case .invalidImage:
            return "Invalid image format"
        case .apiError(let message):
            return "API Error: \(message)"
        case .invalidResponse:
            return "Invalid API response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
