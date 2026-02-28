import AVKit
import AppKit
import Observation

@Observable
class WallpaperManager {
    static let shared = WallpaperManager()

    var isPlaying = false

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var window: NSWindow?

    private var appSupportDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("wall", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let savedFilenameKey = "savedVideoFilename"

    func chooseAndPlay() {
        NSApp.activate()

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a video file for your wallpaper"

        guard panel.runModal() == .OK, let url = panel.url else { return }

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

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        self.player = queuePlayer
        self.looper = playerLooper

        guard let screen = NSScreen.main else { return }

        let playerView = AVPlayerView(frame: NSRect(origin: .zero, size: screen.frame.size))
        playerView.player = queuePlayer
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

        self.window = wallpaperWindow

        queuePlayer.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        player = nil
        looper = nil
        window?.orderOut(nil)
        window = nil
        isPlaying = false
    }
}
