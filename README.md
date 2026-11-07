# MinecraftFriendsKit

A Swift Package for integrating Minecraft friend lists, presence, and friend preferences into macOS apps. Host apps provide Microsoft/Minecraft access tokens, error reporting, and skin resolution through protocols. This package is used by [Swift Craft Launcher](https://github.com/suhang12332/Swift-Craft-Launcher).

## Features

- Minecraft Services friend lists, presence, and player attributes
- SwiftUI friends sheet with pending requests, refresh, and add friend actions
- Optional background presence polling and silent notification hooks
- Protocol-based host integration
- Localized resources via `Bundle.module`

## Entry Points

- `MinecraftFriendsService`: friends and presence API
- `MinecraftFriendsSheetView`: SwiftUI friends sheet
- `MinecraftFriendsPresenceMonitor`: presence polling
- `MinecraftFriendsFriendListMonitor`: friend list polling
- `MinecraftFriendsSheetHost`: host callbacks for the friends sheet
- `MinecraftFriendsPresenceMonitorHost`: host callbacks for presence monitoring

## Requirements

- macOS 14+
- Swift 6
