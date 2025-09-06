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
            print("❌ Could not create ModelContainer: \(error)")
            // HACK: Destructive reset to recover from SwiftData model mismatches
            // This clears the app's Application Support directory where SwiftData stores live.
            // It will delete all user data, but allows the app to relaunch cleanly after schema changes.
            BannanagramApp.resetSwiftDataStores()
            do {
                print("🔁 Retrying ModelContainer creation after clearing stores…")
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
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

    private static func resetSwiftDataStores() {
        let fm = FileManager.default
        do {
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            print("🧹 Clearing Application Support at: \(appSupport.path)")
            if let items = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                for url in items {
                    do {
                        try fm.removeItem(at: url)
                        print("   • Removed: \(url.lastPathComponent)")
                    } catch {
                        print("   ⚠️ Failed to remove: \(url.lastPathComponent) — \(error)")
                    }
                }
            }
        } catch {
            print("⚠️ Failed to access Application Support: \(error)")
        }
    }
}
