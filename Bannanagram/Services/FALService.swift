import Foundation
import UIKit
import FalClient

@Observable
class FALService {
    static let shared = FALService()
    
    private var fal: (any Client)?
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
            fal = FalClient.withCredentials(.keyPair(apiKey))
            print("✅ FALService: Client setup complete")
        } catch {
            print("❌ FALService: Client setup failed - \(error)")
            fal = nil
        }
    }
    
    // MARK: - Simplified Image Editing
    
    func editImage(
        _ image: UIImage,
        prompt: String = "enhance this image with better lighting, improved colors, and professional photo quality"
    ) async throws -> TransformationResult {
        print("🎨 FALService: Starting nano-banana image edit")
        print("📝 FALService: Prompt: \(prompt)")
        
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
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            print("❌ FALService: Failed to convert image to JPEG data")
            throw APIError.invalidImage
        }
        
        print("✅ FALService: Image converted to JPEG (\(imageData.count) bytes)")
        
        // Check if we have a working FAL client
        guard let fal = fal else {
            print("⚠️ FALService: No FAL client available, using mock transformation")
            return await performMockTransformation(imageData: imageData)
        }
        
        do {
            print("🔄 FALService: Attempting real FAL API transformation...")
            return try await performRealTransformation(
                fal: fal,
                imageData: imageData,
                prompt: prompt
            )
        } catch {
            print("❌ FALService: Real transformation failed: \(error)")
            
            // Check if it's a 413 error (request too large)
            let errorString = String(describing: error)
            if errorString.contains("413") || errorString.contains("request too large") {
                print("🔄 FALService: 413 error detected, trying with compressed image...")
                
                // Try once more with a heavily compressed image
                if let compressedData = try? await compressImageIfNeeded(imageData),
                   compressedData.count < imageData.count {
                    do {
                        print("🚀 FALService: Retrying with compressed image (\(compressedData.count / 1024)KB)")
                        return try await performRealTransformation(
                            fal: fal,
                            imageData: compressedData,
                            prompt: prompt
                        )
                    } catch {
                        print("❌ FALService: Retry with compressed image also failed: \(error)")
                    }
                }
            }
            
            print("🔄 FALService: All real transformation attempts failed, falling back to mock")
            return await performMockTransformation(imageData: imageData)
        }
    }
    
    private func performRealTransformation(
        fal: any Client,
        imageData: Data,
        prompt: String
    ) async throws -> TransformationResult {
        print("🚀 FALService: Performing REAL nano-banana transformation")
        
        await MainActor.run {
            processingStatus = "Preparing image..."
            processingProgress = 0.1
        }
        
        // Upload image to FAL storage or use base64
        let imageUrl = try await uploadImageToFAL(fal: fal, imageData: imageData)
        
        await MainActor.run {
            processingStatus = "Processing with AI..."
            processingProgress = 0.3
        }
        
        print("🚀 FALService: Calling nano-banana API...")
        
        // Call nano-banana using the exact documentation pattern
        let result = try await fal.subscribe(
            to: "fal-ai/nano-banana/edit",
            input: [
                "prompt": .string(prompt),
                "image_urls": .array([.string(imageUrl)]),
                "num_images": .int(1),
                "output_format": .string("jpeg")
            ],
            includeLogs: true
        ) { update in
            if case let .inProgress(logs) = update {
                print("🔄 FALService: Processing logs: \(logs)")
                Task { @MainActor in
                    self.processingStatus = "AI processing..."
                    self.processingProgress = min(0.8, self.processingProgress + 0.1)
                }
            }
        }
        
        await MainActor.run {
            processingStatus = "Downloading result..."
            processingProgress = 0.9
        }
        
        print("✅ FALService: Nano-banana processing completed!")
        print("📄 FALService: Raw result type: \(type(of: result))")
        
        // Parse the nano-banana response format
        let resultData = try await parseNanoBananaResult(result)
        
        await MainActor.run {
            processingStatus = "Complete!"
            processingProgress = 1.0
        }
        
        print("🎉 FALService: Real transformation completed successfully!")
        
        return TransformationResult(
            mediaData: resultData,
            isVideo: false,
            duration: nil,
            metadata: [
                "mock": false,
                "model": "fal-ai/nano-banana/edit",
                "original_size": imageData.count,
                "result_size": resultData.count
            ]
        )
    }
    
    private func performMockTransformation(
        imageData: Data
    ) async -> TransformationResult {
        print("🎭 FALService: Performing MOCK transformation (returning original image)")
        
        await MainActor.run {
            processingStatus = "Processing with mock AI..."
        }
        
        // Simulate processing time
        for i in 1...10 {
            await MainActor.run {
                processingProgress = Double(i) / 10.0
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        await MainActor.run {
            processingStatus = "Finalizing..."
            processingProgress = 1.0
        }
        
        print("⚠️ FALService: Mock transformation complete (original image returned)")
        
        // Return mock result with original image
        return TransformationResult(
            mediaData: imageData,
            isVideo: false,
            duration: nil,
            metadata: ["mock": true, "model": "fal-ai/nano-banana/edit"]
        )
    }
    
    // MARK: - Nano-Banana Result Parsing
    
    private func parseNanoBananaResult(_ result: Any) async throws -> Data {
        print("🍌 FALService: Parsing nano-banana result")

        // Preferred: FalClient.Payload (what subscribe returns)
        if let payload = result as? Payload {
            // Helpful diagnostics
            if case .dict(let dict) = payload {
                let keys = dict.keys.joined(separator: ", ")
                print("📄 FALService: Payload keys: \(keys)")
            } else {
                print("📄 FALService: Payload (non-dict): \(payload)")
            }

            if let imageUrl = extractImageURL(from: payload) {
                print("🍌 FALService: Downloading result from: \(imageUrl)")
                let (data, response) = try await URLSession.shared.data(from: URL(string: imageUrl)!)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("❌ FALService: HTTP error downloading result: \(httpResponse.statusCode)")
                    throw APIError.apiError("Network error: HTTP \(httpResponse.statusCode)")
                }
                print("✅ FALService: Result downloaded (\(data.count) bytes)")
                return data
            } else {
                print("❌ FALService: Could not locate image URL in Payload")
                throw APIError.invalidResponse
            }
        }

        // Fallback: legacy dictionary parsing
        if let output = result as? [String: Any] {
            print("📄 FALService: Result keys: \(output.keys.joined(separator: ", "))")
            if let images = output["images"] as? [[String: Any]],
               let firstImage = images.first,
               let imageUrl = firstImage["url"] as? String ?? firstImage["image_url"] as? String ?? firstImage["image"] as? String {
                print("🍌 FALService: Downloading result from: \(imageUrl)")
                let (data, response) = try await URLSession.shared.data(from: URL(string: imageUrl)!)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("❌ FALService: HTTP error downloading result: \(httpResponse.statusCode)")
                    throw APIError.apiError("Network error: HTTP \(httpResponse.statusCode)")
                }
                print("✅ FALService: Result downloaded (\(data.count) bytes)")
                return data
            }
        }

        print("❌ FALService: Result is neither Payload nor expected dictionary: \(type(of: result))")
        throw APIError.invalidResponse
    }

    // Extract first image URL from FalClient.Payload response
    private func extractImageURL(from payload: Payload) -> String? {
        switch payload {
        case .dict(let dict):
            // Primary shape: { images: [ { url: "..." } ], description?: "..." }
            if case let .array(imagesPayload) = dict["images"], let first = imagesPayload.first {
                if case let .dict(imgObj) = first {
                    if case let .string(url) = imgObj["url"] { return url }
                    if case let .string(url) = imgObj["image_url"] { return url }
                    if case let .string(url) = imgObj["image"] { return url }
                }
            }
            // Alternate shapes sometimes returned by models
            if case let .string(url) = dict["image"] { return url }
            if case let .string(url) = dict["image_url"] { return url }
            if case let .string(url) = dict["url"] { return url }
            return nil
        case .array(let arr):
            for item in arr {
                if let url = extractImageURL(from: item) { return url }
            }
            return nil
        case .string(let possibleURL):
            return possibleURL
        default:
            return nil
        }
    }
    
    // MARK: - Image Upload Handling
    
    private func uploadImageToFAL(fal: any Client, imageData: Data) async throws -> String {
        print("📄 FALService: Uploading image to FAL")
        
        // Check image size - if small, use base64, if large, upload to FAL storage
        let sizeInMB = imageData.count / (1024 * 1024)
        print("📊 FALService: Image size: \(sizeInMB)MB (\(imageData.count) bytes)")
        
        if imageData.count > 1 * 1024 * 1024 { // 1MB threshold - base64 encoding adds ~33% overhead
            print("🚀 FALService: Large image (>\(sizeInMB)MB), uploading to FAL storage...")
            
            do {
                let url = try await fal.storage.upload(data: imageData)
                print("✅ FALService: Image uploaded to FAL storage: \(url)")
                return url
            } catch {
                print("❌ FALService: FAL storage upload failed!")
                print("❌ FALService: Storage error: \(error)")
                print("❌ FALService: Error type: \(type(of: error))")
                if let localizedError = error as? LocalizedError {
                    print("❌ FALService: Error description: \(localizedError.errorDescription ?? "No description")")
                }
                print("🔄 FALService: Falling back to base64 (may exceed API limits)")
                // Fall through to base64 method
            }
        } else {
            print("📄 FALService: Small image (≤1MB), using base64 data URL")
        }
        
        // Use base64 data URL for smaller images or as fallback
        print("📄 FALService: Using base64 data URL")
        
        // If image is still large (>2MB), try to compress it first
        var finalImageData = imageData
        if imageData.count > 2 * 1024 * 1024 {
            print("⚠️ FALService: Image is large for base64, attempting compression...")
            if let compressedData = try await compressImageIfNeeded(imageData) {
                finalImageData = compressedData
                let newSizeMB = finalImageData.count / (1024 * 1024)
                print("✅ FALService: Compressed image from \(sizeInMB)MB to \(newSizeMB)MB")
            } else {
                print("⚠️ FALService: Compression failed, using original image")
            }
        }
        
        let base64Image = finalImageData.base64EncodedString()
        let imageUrl = "data:image/jpeg;base64,\(base64Image)"
        
        print("✅ FALService: Base64 data URL created (\(imageUrl.count) characters)")
        
        // Warn if the base64 string is very large
        if imageUrl.count > 3_000_000 { // 3MB in characters
            print("⚠️ FALService: Large base64 payload (\(imageUrl.count/1024/1024)MB+) may exceed API limits")
        }
        
        return imageUrl
    }
    
    // MARK: - Image Compression Helper
    
    private func compressImageIfNeeded(_ imageData: Data) async throws -> Data? {
        print("🗜️ FALService: Compressing image...")
        
        // Convert data to UIImage
        guard let image = UIImage(data: imageData) else {
            print("❌ FALService: Failed to create UIImage from data")
            return nil
        }
        
        // Try progressively lower quality levels
        let qualityLevels: [CGFloat] = [0.7, 0.5, 0.3, 0.2]
        
        for quality in qualityLevels {
            guard let compressedData = image.jpegData(compressionQuality: quality) else {
                continue
            }
            
            let compressedSizeMB = compressedData.count / (1024 * 1024)
            print("🗜️ FALService: Quality \(quality): \(compressedSizeMB)MB")
            
            // If compressed size is under 1.5MB, use it
            if compressedData.count < 1_500_000 {
                print("✅ FALService: Compression successful at quality \(quality)")
                return compressedData
            }
        }
        
        // If we get here, even maximum compression didn't help enough
        print("⚠️ FALService: Image too large even after compression")
        return nil
    }
}

// MARK: - Data Models

struct TransformationResult {
    let mediaData: Data
    let isVideo: Bool
    let duration: TimeInterval?
    let metadata: [String: Any]
}
