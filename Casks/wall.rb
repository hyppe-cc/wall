cask "wall" do
  version "1.0.0"
  sha256 "SHA_OF_YOUR_DMG"

  url "https://github.com/hyppe-cc/wall/releases/download/v#{version}/wall.dmg"
  name "wall"
  desc "Video wallpaper for macOS"
  homepage "https://github.com/hyppe-cc/wall"

  app "wall.app"
end
