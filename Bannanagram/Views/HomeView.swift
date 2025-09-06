import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Photo.dateCreated, order: .reverse) private var photos: [Photo]
    @Query(sort: \ProcessedMedia.dateCreated, order: .reverse) private var processedMedia: [ProcessedMedia]
    @State private var selectedItem: MediaItem?
    @State private var pendingDeleteItem: MediaItem?
    @State private var showDeleteConfirm: Bool = false
    
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
                            .onTapGesture { selectedItem = item }
                            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                pendingDeleteItem = item
                                showDeleteConfirm = true
                            })
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
        .fullScreenCover(item: $selectedItem) { item in
            MediaDetailView(item: item) {
                selectedItem = nil
            }
        }
        .confirmationDialog(
            pendingDeleteItem?.isVideo == true ? "Delete this video?" : "Delete this photo?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = pendingDeleteItem {
                    delete(item)
                }
            }
            Button("Cancel", role: .cancel) { pendingDeleteItem = nil }
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
            let cellSize = UIScreen.main.bounds.width / 3 - 2
            if item.isVideo, let data = item.processedMedia?.mediaData {
                LoopingVideoView(data: data, cornerRadius: 2)
                    .frame(width: cellSize, height: cellSize)
            } else if let imageData = item.thumbnailData ?? item.imageData,
                      let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cellSize, height: cellSize)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: cellSize, height: cellSize)
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

// MARK: - Deletion
extension HomeView {
    private func delete(_ item: MediaItem) {
        if let media = item.processedMedia {
            modelContext.delete(media)
        } else if let photo = item.photo {
            modelContext.delete(photo)
        }
        do {
            try modelContext.save()
        } catch {
            print("HomeView: failed to delete item: \(error)")
        }
        pendingDeleteItem = nil
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Photo.self, inMemory: true)
}
