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

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
