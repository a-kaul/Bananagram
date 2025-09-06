import Foundation

struct APIConfiguration {
    enum APIError: Error, LocalizedError {
        case missingAPIKey(String)
        case invalidConfiguration
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey(let keyName):
                return "Missing API key: \(keyName). Please check your environment configuration."
            case .invalidConfiguration:
                return "Invalid API configuration. Please verify your setup."
            }
        }
    }
    
    static let shared = APIConfiguration()
    
    private init() {}
    
    var falAIAPIKey: String {
        get throws {
            guard let key = ProcessInfo.processInfo.environment["FAL_AI_API_KEY"],
                  !key.isEmpty else {
                throw APIError.missingAPIKey("FAL_AI_API_KEY")
            }
            return key
        }
    }
    
    var geminiAPIKey: String {
        get throws {
            guard let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
                  !key.isEmpty else {
                throw APIError.missingAPIKey("GEMINI_API_KEY")
            }
            return key
        }
    }
    
    func validateConfiguration() throws {
        _ = try falAIAPIKey
        _ = try geminiAPIKey
    }
    
    var isConfigured: Bool {
        do {
            try validateConfiguration()
            return true
        } catch {
            return false
        }
    }
}