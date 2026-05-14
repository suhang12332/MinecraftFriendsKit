# MinecraftFriendsKit

Swift Package：在 macOS 应用里集成 **Minecraft 正版好友列表、在线状态（Presence）、账号好友偏好** 等能力。通过协议由宿主提供 Microsoft / Minecraft 访问令牌、错误上报与皮肤解析，避免 Kit 直接依赖具体 App 类型。本包服务于 [Swift Craft Launcher](https://github.com/suhang12332/Swift-Craft-Launcher)

## 要求

- macOS 14+
- Swift 6（Package 使用 `swift-tools-version: 6.1`，`swiftLanguageModes: .v6`）

## 功能概览

- 调用 Mojang **Minecraft Services** 生产环境接口（好友、Presence、玩家属性）。
- SwiftUI **好友 Sheet**（列表、待处理请求、刷新、添加好友等）。
- 可选的 **后台 Presence 轮询** 与静默通知钩子（由宿主实现通知发送）。
- SPM 内 **本地化资源**（`Resources` + `Bundle.module`），默认语言为简体中文。
