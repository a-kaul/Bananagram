import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var isProcessingUpload = false
    @State private var showingAIAnalysis = false
    @State private var currentPhoto: Photo?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Magic")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Transform your photos with AI")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                
                Spacer()
                
                // Camera Preview or Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                        .frame(height: 300)
                        .overlay {
                            if isProcessingUpload {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Processing image...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    
                                    Text("Select or capture a photo\nto get started")
                                        .multilineTextAlignment(.center)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Camera Button (Primary)
                    Button {
                        requestCameraPermission { granted in
                            if granted {
                                showingCamera = true
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                            Text("Take Photo")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Photo Library Button
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 1,
                        matching: .images
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title3)
                            Text("Choose from Library")
                                .font(.headline)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 50)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .onChange(of: selectedItems) { _, newItems in
            Task {
                await handlePhotosPickerSelection(newItems)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCapture { image in
                capturedImage = image
                Task {
                    await handleCapturedImage(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showingAIAnalysis) {
            if let photo = currentPhoto {
                AIAnalysisView(photo: photo) {
                    showingAIAnalysis = false
                    currentPhoto = nil
                }
            }
        }
    }
    
    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func handlePhotosPickerSelection(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        
        await MainActor.run {
            isProcessingUpload = true
        }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await createPhotoFromData(data, fileName: "library_photo.jpg")
            }
        } catch {
            print("Error loading photo: \(error)")
        }
        
        await MainActor.run {
            isProcessingUpload = false
            selectedItems = []
        }
    }
    
    private func handleCapturedImage(_ image: UIImage) async {
        await MainActor.run {
            isProcessingUpload = true
            showingCamera = false
        }
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        await createPhotoFromData(data, fileName: "captured_photo.jpg")
        
        await MainActor.run {
            isProcessingUpload = false
        }
    }
    
    private func createPhotoFromData(_ data: Data, fileName: String) async {
        let photo = Photo(imageData: data, originalFileName: fileName)
        
        await MainActor.run {
            modelContext.insert(photo)
            
            do {
                try modelContext.save()
                currentPhoto = photo
                showingAIAnalysis = true
            } catch {
                print("Error saving photo: \(error)")
            }
        }
    }
}

struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        
        init(_ parent: CameraCapture) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CameraView()
        .modelContainer(for: Photo.self, inMemory: true)
}