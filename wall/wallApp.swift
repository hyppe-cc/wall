import SwiftUI

@main
struct wallApp: App {
    @State private var manager = WallpaperManager.shared

    init() {
        DispatchQueue.main.async {
            WallpaperManager.shared.resumeIfPossible()
        }
    }

    var body: some Scene {
        MenuBarExtra("Wall", systemImage: "play.rectangle.fill") {
            Button("Choose Video...") {
                manager.chooseAndPlay()
            }

            if manager.isPlaying {
                Button("Stop Wallpaper") {
                    manager.stop()
                }
            }

            Divider()

            Button("Quit") {
                manager.stop()
                NSApp.terminate(nil)
            }
        }
    }
}
