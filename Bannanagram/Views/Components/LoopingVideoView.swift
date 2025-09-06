import SwiftUI
import AVKit

struct LoopingVideoView: UIViewRepresentable {
    let data: Data
    let cornerRadius: CGFloat
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = cornerRadius
        context.coordinator.setup(with: data, in: view)
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {}
    
    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.teardown()
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
    
    class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var tempURL: URL?
        
        func setup(with data: Data, in view: PlayerView) {
            do {
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".mp4")
                try data.write(to: url, options: .atomic)
                tempURL = url
                let item = AVPlayerItem(url: url)
                let queue = AVQueuePlayer()
                queue.isMuted = true
                let looper = AVPlayerLooper(player: queue, templateItem: item)
                self.player = queue
                self.looper = looper
                if let layer = view.playerLayer as AVPlayerLayer? {
                    layer.player = queue
                }
                queue.play()
            } catch {
                print("LoopingVideoView: failed to write temp video: \(error)")
            }
        }
        
        func teardown() {
            player?.pause()
            player = nil
            looper = nil
            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
                tempURL = nil
            }
        }
    }
}

