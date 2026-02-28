import ServiceManagement
import SwiftUI

@main
struct wallApp: App {
    @State private var manager = WallpaperManager.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

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

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Failed to update login item: \(error)")
                        launchAtLogin = !newValue
                    }
                }

            Button("Quit") {
                manager.stop()
                NSApp.terminate(nil)
            }
        }
    }
}
