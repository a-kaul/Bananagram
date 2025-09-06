import SwiftUI
import SwiftData

struct SuggestionSelectionView: View {
    let photo: Photo
    let suggestions: [TransformationSuggestion]
    let onComplete: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSuggestion: TransformationSuggestion?
    @State private var showingProcessing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Magic Filters")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose your magical transformation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.horizontal)
            
            // Original Image Preview
            if let uiImage = photo.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 20)
            }
            
            // Suggestions Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(suggestions.sorted(by: { $0.orderIndex < $1.orderIndex })) { suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            isSelected: selectedSuggestion?.id == suggestion.id
                        ) {
                            selectedSuggestion = suggestion
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 30)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                if let selected = selectedSuggestion {
                    Button {
                        startProcessing()
                    } label: {
                        HStack(spacing: 12) {
                            if selected.type == .videoAnimation {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.title3)
                            }
                            
                            Text("Apply \(selected.title)")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Estimated time
                    Text("Estimated time: \(Int(selected.estimatedProcessingTime))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Select a magic filter to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button("Back") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingProcessing) {
            if let suggestion = selectedSuggestion {
                ProcessingView(
                    photo: photo,
                    suggestion: suggestion,
                    onComplete: onComplete
                )
            }
        }
    }
    
    private func startProcessing() {
        guard selectedSuggestion != nil else { return }
        showingProcessing = true
    }
}

struct SuggestionCard: View {
    let suggestion: TransformationSuggestion
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type Badge
            HStack {
                TypeBadge(type: suggestion.type)
                Spacer()
                ConfidenceBadge(confidence: suggestion.confidence)
            }
            
            // Title and Description
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(suggestion.suggestionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Preview Placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 80)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: suggestion.type == .videoAnimation ? "play.circle" : "photo")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Preview")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            
            Spacer()
        }
        .frame(width: 160, height: 200)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

struct TypeBadge: View {
    let type: TransformationType
    
    var body: some View {
        Text(type.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .foregroundColor(badgeColor)
            .cornerRadius(8)
    }
    
    private var badgeColor: Color {
        switch type {
        case .utilityEdit:
            return .green
        case .creativeTransform:
            return .purple
        case .videoAnimation:
            return .orange
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.yellow)
    }
}

#Preview {
    let mockPhoto = Photo(imageData: Data(), originalFileName: "test.jpg")
    let mockSuggestions = [
        TransformationSuggestion(
            photoId: mockPhoto.id,
            type: .utilityEdit,
            title: "Enhance Lighting",
            description: "Brighten shadows and balance exposure",
            reasoning: "Test",
            confidence: 0.9,
            falModelId: "test",
            orderIndex: 0
        )
    ]
    
    return SuggestionSelectionView(photo: mockPhoto, suggestions: mockSuggestions) {
        print("Selection complete")
    }
    .modelContainer(for: Photo.self, inMemory: true)
}