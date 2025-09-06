import SwiftUI
import SwiftData
import UIKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var photos: [Photo]
    @Query private var processedMedia: [ProcessedMedia]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 12) {
                        if let avatar = UIImage(named: "ProfileAvatar") {
                            Image(uiImage: avatar)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                                .shadow(radius: 3)
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                }
                        }
                        
                        Text("BananaGram User")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Creating magic with AI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Stats
                    HStack(spacing: 40) {
                        StatView(number: photos.count, label: "Photos")
                        StatView(number: processedMedia.filter { $0.isComplete }.count, label: "Enhanced")
                        StatView(number: processedMedia.reduce(0) { $0 + $1.shareCount }, label: "Shares")
                    }
                    .padding(.horizontal)
                    
                    // Settings
                    VStack(spacing: 0) {
                        SettingsRow(icon: "key", title: "API Configuration", subtitle: apiConfigStatus)
                        Divider().padding(.horizontal)
                        SettingsRow(icon: "info.circle", title: "About BananaGram")
                        Divider().padding(.horizontal)
                        SettingsRow(icon: "questionmark.circle", title: "Help & Support")
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var apiConfigStatus: String {
        do {
            try APIConfiguration.shared.validateConfiguration()
            return "Configured"
        } catch {
            return "Not configured"
        }
    }
}

struct StatView: View {
    let number: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(number)")
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    
    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: Photo.self, inMemory: true)
}
