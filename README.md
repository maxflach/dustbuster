# DustBuster

A native macOS 14+ disk cleanup utility built with Swift/SwiftUI.

## Features

- **Smart Cleanup** — scans and removes system caches, app logs, trash, browser caches, and Docker artifacts
- **Space Lens** — visual treemap + file browser showing disk usage by folder
- **Menu Bar Extra** — quick access to disk space info and one-click clean
- **Launch at Login** — optional auto-start via `SMAppService`

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`

## Setup

```bash
# Install xcodegen if needed
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode
open DustBuster.xcodeproj
```

Then build and run with ⌘R.

## Architecture

```
DustBuster/
├── DustBusterApp.swift          # @main, MenuBarExtra scene
├── AppDelegate.swift            # Keep-alive after window close
├── Models/
│   ├── FileSystemNode.swift     # Tree node with size rollup
│   ├── CleanupCategory.swift    # Enum of cleanup targets + paths
│   └── CleanupItem.swift        # Individual item + scan result
├── Services/
│   ├── DiskScannerService.swift   # Async recursive scanner
│   ├── CleanupService.swift       # Size calc + deletion + Docker CLI
│   └── LaunchAtLoginService.swift # SMAppService wrapper
├── ViewModels/
│   ├── CleanupViewModel.swift     # Scan/clean state machine
│   └── SpaceLensViewModel.swift   # Space Lens state + navigation
└── Views/
    ├── ContentView.swift          # NavigationSplitView
    ├── Sidebar/SidebarView.swift
    ├── Cleanup/
    │   ├── CleanupView.swift
    │   └── CleanupCategoryRow.swift
    ├── SpaceLens/
    │   ├── SpaceLensView.swift
    │   ├── TreemapView.swift      # Squarified treemap on Canvas
    │   └── FileBrowserView.swift  # Table-based browser
    ├── MenuBar/MenuBarStatusView.swift
    └── SettingsView.swift
```

## Notes

- **Sandbox is disabled** to allow access to `/Library/Caches` and system paths — distribute outside the App Store or via direct download
- **Full Disk Access** is recommended for cleaning outside `~/Library`; the Settings panel links to System Preferences
- Docker cleanup shells out to the `docker` CLI; Docker Desktop must be running
- The treemap uses a squarified layout algorithm for good aspect ratios
