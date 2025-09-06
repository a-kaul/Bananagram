//
//  BannanagramApp.swift
//  Bannanagram
//
//  Created by Arjun Kaul on 9/6/25.
//

import SwiftUI
import SwiftData

@main
struct BannanagramApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Photo.self,
            ImageAnalysis.self,
            TransformationSuggestion.self,
            ProcessedMedia.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        print("🚀 BananaGram App Starting...")
        print("🔧 Initializing API Configuration...")
        
        // Force initialization of APIConfiguration to see debug logs
        let _ = APIConfiguration.shared
        
        print("🔧 Configuration check: \(APIConfiguration.shared.isConfigured ? "✅ Configured" : "❌ Missing keys")")
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
