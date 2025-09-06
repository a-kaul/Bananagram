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
        Based on this image analysis, generate up to 4 highly relevant transformation suggestions.
        
        Distribution requirements:
        - Include EXACTLY ONE (1) Video Animation suggestion.
        - Include up to THREE (3) image-to-image suggestions (Utility Edit and/or Creative Transform).
        - Always include at least TWO (2) image-to-image suggestions in total.
        
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
        - You MUST include exactly one suggestion that converts the image into a short animated video using fal.ai’s image-to-video stylization model.
        - Use: "fal_model": "fal-ai/bytedance/video-stylize"
        - Provide a single, simple style name in parameters under the key "style" (e.g., "Manga style", "Watercolor", "Cyberpunk neon"). Keep the style concise. Do NOT add complex parameter sets.
        - You MUST still include at least TWO image-to-image suggestions as well.
        
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
        print("🔍 GeminiService: Generating suggestions…")
        print("📝 GeminiService: Prompt (\(prompt.count) chars):\n\(prompt)")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.8,
                "maxOutputTokens": 2048,
                "thinkingConfig": [
                    "thinkingBudget": 0
                ]
            ]
        ]
        
        // Target Gemini 2.5 Flash for suggestion generation
        let url = URL(string: "\(baseURL)/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            print("📥 GeminiService: Suggestions HTTP status: \(http.statusCode)")
        }
        print("📄 GeminiService: Raw response bytes: \(data.count)")
        if let raw = String(data: data, encoding: .utf8) {
            let snippet = raw.count > 2000 ? String(raw.prefix(2000)) + "…" : raw
            print("📃 GeminiService: Raw response snippet:\n\(snippet)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.apiError("Failed to generate suggestions")
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let content = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw APIError.invalidResponse
        }
        print("🧩 GeminiService: Content length \(content.count)")
        let contentPreview = content.count > 2000 ? String(content.prefix(2000)) + "…" : content
        print("🧾 GeminiService: Content preview:\n\(contentPreview)")
        
        let suggestions = try parseSuggestionsResponse(content)
        print("✅ GeminiService: Parsed suggestions count: \(suggestions.count)")
        for (idx, s) in suggestions.enumerated() {
            print("   [#\(idx)] type=\(s.type) title=\(s.title) model=\(s.falModel) paramsKeys=\(Array(s.parameters.keys))")
        }

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
        if filtered.count != suggestions.count {
            print("⚖️ GeminiService: Filtered suggestions from \(suggestions.count) to \(filtered.count) (max 1 video stylize)")
        }

        // If no video suggestion made it through, inject a simple fallback to ensure we always have one
        var ensured = filtered
        let hasVideo = ensured.contains { $0.falModel == "fal-ai/bytedance/video-stylize" || $0.type == "video_animation" }
        if !hasVideo {
            let fallbackStyle = analysis.style.isEmpty ? "Watercolor" : analysis.style
            let fallback = SuggestionResult(
                type: "video_animation",
                title: "Video Stylize (Bytedance)",
                description: "Turn your image into a short stylized animation using a simple style.",
                reasoning: "A subtle animated treatment can add motion and interest to this scene.",
                confidence: 0.75,
                falModel: "fal-ai/bytedance/video-stylize",
                parameters: ["style": fallbackStyle],
                processingTime: 45.0
            )
            ensured.append(fallback)
            print("🧩 GeminiService: Injected fallback video suggestion with style=\(fallbackStyle)")
        }

        // Trim to at most 4 items
        if ensured.count > 4 { ensured = Array(ensured.prefix(4)) }
        return ensured
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
        print("🔎 GeminiService: Parsing suggestions response (len=\(content.count))")
        // Extract JSON from the response (may have markdown formatting)
        let jsonStart = content.range(of: "{")
        let jsonEnd = content.range(of: "}", options: .backwards)
        
        guard let start = jsonStart?.lowerBound,
              let end = jsonEnd?.upperBound else {
            print("❌ GeminiService: Failed to locate JSON braces in content")
            throw APIError.invalidResponse
        }
        
        let jsonString = String(content[start..<end])
        print("🧪 GeminiService: Extracted JSON substring (len=\(jsonString.count)):")
        let jsonPreview = jsonString.count > 2000 ? String(jsonString.prefix(2000)) + "…" : jsonString
        print(jsonPreview)
        let jsonData = jsonString.data(using: .utf8)!
        
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let suggestionsArray = parsed["suggestions"] as? [[String: Any]] ?? []
        print("📊 GeminiService: suggestions array count=\(suggestionsArray.count)")
        if suggestionsArray.isEmpty { print("⚠️ GeminiService: suggestions array is empty") }
        
        let results = suggestionsArray.compactMap { dict -> SuggestionResult? in
            // Required string fields
            guard let type = dict["type"] as? String,
                  let title = dict["title"] as? String,
                  let description = dict["description"] as? String,
                  let reasoning = dict["reasoning"] as? String else {
                print("⚠️ GeminiService: Skipping invalid suggestion (missing required strings). Keys=\(Array(dict.keys))")
                return nil
            }

            // Confidence can be Double or Int
            var confidence: Double = 0.8
            if let c = dict["confidence"] as? Double {
                confidence = c
            } else if let ci = dict["confidence"] as? Int {
                confidence = Double(ci)
            } else {
                print("ℹ️ GeminiService: Missing confidence; defaulting to 0.8 for \(title)")
            }

            // fal_model may be null/missing; map fallback by type
            let rawFalModel = dict["fal_model"] as? String
            let falModel = (rawFalModel?.isEmpty == false ? rawFalModel! : fallbackFalModel(for: type))
            if rawFalModel == nil || rawFalModel?.isEmpty == true {
                print("🔁 GeminiService: Using fallback fal_model '\(falModel)' for type=\(type) title=\(title)")
            }

            let parameters = dict["parameters"] as? [String: Any] ?? [:]

            // processing_time can be Double or Int
            var processingTime: TimeInterval = 15.0
            if let t = dict["processing_time"] as? Double { processingTime = t }
            else if let ti = dict["processing_time"] as? Int { processingTime = TimeInterval(ti) }

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
        print("✅ GeminiService: Compact mapped suggestions=\(results.count)")
        return results
    }

    private func fallbackFalModel(for type: String) -> String {
        switch type {
        case "utility_edit":
            return "fal-ai/nano-banana/edit"
        case "creative_transform":
            return "fal-ai/nano-banana/edit"
        case "video_animation":
            return "fal-ai/bytedance/video-stylize"
        default:
            return "fal-ai/nano-banana/edit"
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
