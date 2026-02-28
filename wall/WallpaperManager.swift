import AVKit
import AppKit
import CoreImage
import Observation

@Observable
class WallpaperManager {
    static let shared = WallpaperManager()

    var isPlaying = false

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var windows: [NSWindow] = []
    private var playingURL: URL?
    private var screenObserver: NSObjectProtocol?

    private var appSupportDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("wall", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let savedFilenameKey = "savedVideoFilename"

    private init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func chooseAndPlay() {
        NSApp.activate()

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a video file for your wallpaper"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        playVideo(from: url)
    }

    func playVideo(from url: URL) {
        cleanAppSupportDir()

        let destination = appSupportDir.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            print("Failed to copy video: \(error)")
            return
        }

        UserDefaults.standard.set(url.lastPathComponent, forKey: Self.savedFilenameKey)
        play(url: destination)
    }

    func resumeIfPossible() {
        guard let filename = UserDefaults.standard.string(forKey: Self.savedFilenameKey) else { return }
        let fileURL = appSupportDir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        play(url: fileURL)
    }

    private func cleanAppSupportDir() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: appSupportDir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    private func play(url: URL) {
        stop()

        playingURL = url

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        self.player = queuePlayer
        self.looper = playerLooper

        createWindows(for: queuePlayer)

        setBlurredWallpaper(from: url)
        queuePlayer.play()
        isPlaying = true
    }

    private func createWindows(for player: AVQueuePlayer) {
        for screen in NSScreen.screens {
            let playerView = AVPlayerView(frame: NSRect(origin: .zero, size: screen.frame.size))
            playerView.player = player
            playerView.controlsStyle = .none
            playerView.videoGravity = .resizeAspectFill
            playerView.autoresizingMask = [.width, .height]

            let wallpaperWindow = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            wallpaperWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            wallpaperWindow.isOpaque = true
            wallpaperWindow.backgroundColor = .black
            wallpaperWindow.ignoresMouseEvents = true
            wallpaperWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            wallpaperWindow.canHide = false
            wallpaperWindow.contentView = playerView
            wallpaperWindow.orderFront(nil)

            windows.append(wallpaperWindow)
        }
    }

    private func handleScreenChange() {
        guard isPlaying, let player = self.player else { return }

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()

        createWindows(for: player)
    }

    private func setBlurredWallpaper(from url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        generator.generateCGImageAsynchronously(for: .zero) { [weak self] image, _, error in
            if let error {
                print("Failed to extract frame: \(error)")
                return
            }
            guard let self, let image else { return }
            self.applyBlurredWallpaper(from: image)
        }
    }

    private func applyBlurredWallpaper(from cgImage: CGImage) {
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent

        // Clamp edges to avoid dark border artifacts from blur
        let clamped = ciImage.clampedToExtent()

        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
        blurFilter.setValue(clamped, forKey: kCIInputImageKey)
        blurFilter.setValue(40.0, forKey: kCIInputRadiusKey)

        guard let blurredOutput = blurFilter.outputImage else { return }

        let cropped = blurredOutput.cropped(to: extent)

        let context = CIContext()
        guard let renderedCG = context.createCGImage(cropped, from: cropped.extent) else { return }

        // Save as PNG with unique name so macOS detects the change
        let pngURL = appSupportDir.appendingPathComponent("blurred_wallpaper_\(UUID().uuidString).png")
        let rep = NSBitmapImageRep(cgImage: renderedCG)
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try pngData.write(to: pngURL)
        } catch {
            print("Failed to write blurred wallpaper: \(error)")
            return
        }

        // Set native wallpaper on all screens
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(pngURL, for: screen, options: [:])
        }
    }

    func stop() {
        player?.pause()
        player = nil
        looper = nil
        playingURL = nil
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        isPlaying = false
    }
}
