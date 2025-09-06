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

    // Resolved configuration used at runtime. Starts with process environment
    // and is augmented with values loaded from bundled config files (e.g. xcconfig).
    private let runtimeEnv: [String: String]

    private init() {
        // Start with current process environment
        var merged: [String: String] = ProcessInfo.processInfo.environment

        // If a Development.xcconfig is bundled as a resource, merge its values.
        if let xcconfigURL = Bundle.main.url(forResource: "Development", withExtension: "xcconfig") {
            let xcVals = Self.parseKeyValueFile(at: xcconfigURL, separator: "=")
            // Only merge expected keys to avoid pulling unrelated build settings
            for key in ["FAL_AI_API_KEY", "GEMINI_API_KEY"] {
                if merged[key] == nil, let val = xcVals[key], !val.isEmpty {
                    merged[key] = val
                }
            }
        }

        // Optionally support a bundled .env file for local runs (debug/dev only)
        if let envURL = Bundle.main.url(forResource: ".env", withExtension: nil) {
            let envVals = Self.parseKeyValueFile(at: envURL, separator: "=")
            for key in ["FAL_AI_API_KEY", "GEMINI_API_KEY"] {
                if merged[key] == nil, let val = envVals[key], !val.isEmpty {
                    merged[key] = val
                }
            }
        }

        self.runtimeEnv = merged
        logEnvironmentDebugInfo()
    }
    
    private func logEnvironmentDebugInfo() {
        print("🔧 APIConfiguration Debug Info:")
        print("📱 App Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("📁 Environment Variables Count: \(runtimeEnv.count)")
        
        // Log presence of our keys (without values for security)
        let hasFailKey = runtimeEnv["FAL_AI_API_KEY"] != nil
        let hasGeminiKey = runtimeEnv["GEMINI_API_KEY"] != nil
        
        print("🔑 FAL_AI_API_KEY present: \(hasFailKey)")
        print("🔑 GEMINI_API_KEY present: \(hasGeminiKey)")
        
        if hasFailKey {
            let falKey = runtimeEnv["FAL_AI_API_KEY"] ?? ""
            print("🔑 FAL_AI_API_KEY length: \(falKey.count) characters")
            print("🔑 FAL_AI_API_KEY starts with: \(String(falKey.prefix(8)))...")
        }
        
        if hasGeminiKey {
            let geminiKey = runtimeEnv["GEMINI_API_KEY"] ?? ""
            print("🔑 GEMINI_API_KEY length: \(geminiKey.count) characters")
            print("🔑 GEMINI_API_KEY starts with: \(String(geminiKey.prefix(8)))...")
        }
        
        // Log all environment variables starting with our prefixes (for debugging xcconfig loading)
        print("🔍 Environment variables containing 'API':")
        for (key, value) in runtimeEnv {
            if key.contains("API") || key.contains("FAL") || key.contains("GEMINI") {
                let maskedValue = value.count > 8 ? "\(String(value.prefix(8)))..." : "[short]"
                print("   \(key) = \(maskedValue)")
            }
        }
    }
    
    var falAIAPIKey: String {
        get throws {
            print("🔍 Attempting to retrieve FAL_AI_API_KEY...")
            guard let key = runtimeEnv["FAL_AI_API_KEY"],
                  !key.isEmpty else {
                print("❌ FAL_AI_API_KEY not found or empty")
                throw APIError.missingAPIKey("FAL_AI_API_KEY")
            }
            print("✅ FAL_AI_API_KEY retrieved successfully (length: \(key.count))")
            return key
        }
    }
    
    var geminiAPIKey: String {
        get throws {
            print("🔍 Attempting to retrieve GEMINI_API_KEY...")
            guard let key = runtimeEnv["GEMINI_API_KEY"],
                  !key.isEmpty else {
                print("❌ GEMINI_API_KEY not found or empty")
                throw APIError.missingAPIKey("GEMINI_API_KEY")
            }
            print("✅ GEMINI_API_KEY retrieved successfully (length: \(key.count))")
            return key
        }
    }
    
    func validateConfiguration() throws {
        print("🔧 Validating API configuration...")
        do {
            _ = try falAIAPIKey
            _ = try geminiAPIKey
            print("✅ All API keys validated successfully")
        } catch {
            print("❌ API configuration validation failed: \(error)")
            throw error
        }
    }
    
    var isConfigured: Bool {
        do {
            try validateConfiguration()
            return true
        } catch {
            print("⚠️ API configuration check failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Helpers
extension APIConfiguration {
    // Parses simple KEY = VALUE style files. Lines starting with `//` or `#` are ignored.
    // Values are trimmed and unquoted if wrapped in single/double quotes.
    static func parseKeyValueFile(at url: URL, separator: String) -> [String: String] {
        guard let raw = try? String(contentsOf: url) else { return [:] }
        var dict: [String: String] = [:]
        raw.split(whereSeparator: \.isNewline).forEach { lineSub in
            var line = String(lineSub)
            // Remove inline comments starting with // or #
            if let range = line.range(of: "//") { line = String(line[..<range.lowerBound]) }
            if let range = line.range(of: "#"), line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                line = ""
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let parts = trimmed.split(separator: Character(separator), maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { return }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            dict[key] = value
        }
        return dict
    }
}
