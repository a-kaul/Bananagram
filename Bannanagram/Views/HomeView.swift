import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Photo.dateCreated, order: .reverse) private var photos: [Photo]
    @Query(sort: \ProcessedMedia.dateCreated, order: .reverse) private var processedMedia: [ProcessedMedia]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(allMediaItems, id: \.id) { item in
                        MediaGridItem(item: item)
                    }
                }
                .padding(.horizontal, 1)
            }
            .navigationTitle("BananaGram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Settings or menu action
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
        }
    }
    
    private var allMediaItems: [MediaItem] {
        var items: [MediaItem] = []
        
        // Add completed processed media
        for media in processedMedia where media.isComplete {
            items.append(MediaItem(processedMedia: media))
        }
        
        // Add original photos that haven't been processed yet
        for photo in photos where photo.processedVersions.isEmpty {
            items.append(MediaItem(photo: photo))
        }
        
        return items.sorted { $0.dateCreated > $1.dateCreated }
    }
}

struct MediaItem: Identifiable {
    let id = UUID()
    let photo: Photo?
    let processedMedia: ProcessedMedia?
    let dateCreated: Date
    let isVideo: Bool
    
    init(photo: Photo) {
        self.photo = photo
        self.processedMedia = nil
        self.dateCreated = photo.dateCreated
        self.isVideo = false
    }
    
    init(processedMedia: ProcessedMedia) {
        self.photo = nil
        self.processedMedia = processedMedia
        self.dateCreated = processedMedia.dateCreated
        self.isVideo = processedMedia.isVideo
    }
    
    var imageData: Data? {
        processedMedia?.mediaData ?? photo?.imageData
    }
    
    var thumbnailData: Data? {
        processedMedia?.thumbnailData ?? photo?.imageData
    }
}

struct MediaGridItem: View {
    let item: MediaItem
    
    var body: some View {
        ZStack {
            if let imageData = item.thumbnailData ?? item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width / 3 - 2, 
                           height: UIScreen.main.bounds.width / 3 - 2)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: UIScreen.main.bounds.width / 3 - 2, 
                           height: UIScreen.main.bounds.width / 3 - 2)
            }
            
            if item.isVideo {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding(4)
                    }
                }
            }
        }
        .cornerRadius(2)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Photo.self, inMemory: true)
}