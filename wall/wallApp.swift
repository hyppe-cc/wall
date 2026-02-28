import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@main
struct wallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        WallpaperManager.shared.resumeIfPossible()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "Wall")

        let dropView = DropView(frame: button.bounds)
        dropView.autoresizingMask = [.width, .height]
        dropView.onClick = { [weak self] in self?.showMenu() }
        button.addSubview(dropView)
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let chooseItem = NSMenuItem(title: "Choose Video...", action: #selector(chooseVideo), keyEquivalent: "")
        chooseItem.target = self
        menu.addItem(chooseItem)

        if WallpaperManager.shared.isPlaying {
            let stopItem = NSMenuItem(title: "Stop Wallpaper", action: #selector(stopWallpaper), keyEquivalent: "")
            stopItem.target = self
            menu.addItem(stopItem)
        }

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func chooseVideo() {
        WallpaperManager.shared.chooseAndPlay()
    }

    @objc private func stopWallpaper() {
        WallpaperManager.shared.stop()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }

    @objc private func quitApp() {
        WallpaperManager.shared.stop()
        NSApp.terminate(nil)
    }
}

private class DropView: NSView {
    private static let videoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return isValidVideoDrag(sender) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = fileURL(from: sender), isVideoURL(url) else { return false }
        WallpaperManager.shared.playVideo(from: url)
        return true
    }

    private func isValidVideoDrag(_ info: NSDraggingInfo) -> Bool {
        guard let url = fileURL(from: info) else { return false }
        return isVideoURL(url)
    }

    private func fileURL(from info: NSDraggingInfo) -> URL? {
        guard let item = info.draggingPasteboard.pasteboardItems?.first,
              let data = item.data(forType: .fileURL),
              let url = URL(dataRepresentation: data, relativeTo: nil) else { return nil }
        return url
    }

    private func isVideoURL(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return Self.videoTypes.contains(where: { type.conforms(to: $0) })
    }
}
