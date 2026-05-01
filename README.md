# MayoBG

A macOS menu bar app that automatically changes your desktop wallpaper with high-resolution photos from Unsplash.

<p align="center">
  <img src="media/1.png" width="320" alt="Menu bar">
  <img src="media/2.png" width="320" alt="Settings">
</p>
<p align="center">
  <img src="media/3.png" width="320" alt="About photo">
  <img src="media/4.png" width="320" alt="Channels">
</p>

## Features

- Lives in the menu bar — no Dock icon, no windows
- High-resolution wallpapers from Unsplash via channels (search, collections, users)
- Configurable auto-rotate interval
- Multi-monitor support
- Wallpaper history
- Photographer attribution (required by Unsplash Terms)

## Getting Started

### 1. Unsplash API Key

You need a free Unsplash API key. [Create one here](https://unsplash.com/developers) (sign up as a developer, create a new app, and copy the Access Key).

### 2. Insert the API Key

Open the Settings panel from the menu bar icon, go to the **API** tab, paste your key, and click **Save Key**. The key is stored in UserDefaults.

Alternatively, you can set it directly by editing `KeychainService.swift`:

```swift
// KeychainService.swift, line ~8 — replace with your key
// The key is stored via UserDefaults under "unsplash_api_key"
```

### 3. Build & Run

```bash
# Build
xcodebuild -project MayoBG.xcodeproj -scheme MayoBG -configuration Debug build

# Open in Xcode
open MayoBG.xcodeproj
```

## Tech Stack

- Swift + SwiftUI (Liquid Glass design system)
- macOS 26+
- Unsplash REST API

## Contributing

Pull requests are welcome. For major changes, open an issue first to discuss what you'd like to change.

## License

MIT
