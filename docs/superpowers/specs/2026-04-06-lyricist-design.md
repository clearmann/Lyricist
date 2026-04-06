# Lyricist — macOS Spotify 桌面歌词显示应用

## 概述

Lyricist 是一个 macOS 桌面应用，通过 AppleScript 检测 Spotify 播放状态，从第三方 API 获取歌词，以悬浮窗形式同步显示在桌面上。同时常驻菜单栏，提供快速控制入口。

## 产品定义

### 核心模式

- **桌面悬浮歌词**：始终浮在最上层，叠在其他窗口上方显示当前歌词
- **菜单栏常驻**：显示歌词内容（跑马灯滚动），点击展开设置面板和歌曲信息

### 功能范围

| 功能 | MVP | 完整版 |
|------|-----|--------|
| 悬浮窗 - 纯文字无背景 | ✅ | ✅ |
| 悬浮窗 - 胶囊气泡 | ❌ | ✅ |
| 悬浮窗 - 风格切换 | ❌ | ✅ |
| 逐行歌词同步 | ✅ | ✅ |
| 逐字歌词同步 | ❌ | ✅ |
| 菜单栏图标 | ✅ | ✅ |
| 菜单栏跑马灯歌词 | ❌ | ✅ |
| Popover - 简单控制 | ✅ | ✅ |
| Popover - 歌曲信息 + 完整设置 | ❌ | ✅ |
| LRCLIB 歌词源 | ✅ | ✅ |
| 多歌词源 fallback | ❌ | ✅ |
| 歌词时间偏移微调 | ❌ | ✅ |

## 架构

```
┌─────────────────────────────────────────────┐
│                   App Layer                  │
│  NSStatusItem (菜单栏) + NSPanel (悬浮窗)     │
└──────────────┬──────────────┬───────────────┘
               │              │
       ┌───────▼───────┐  ┌──▼──────────────┐
       │  LyricsEngine │  │  SettingsStore   │
       │  (核心引擎)    │  │  (用户配置持久化) │
       └───┬───────┬───┘  └─────────────────┘
           │       │
    ┌──────▼──┐ ┌──▼───────────┐
    │ Spotify │ │ LyricsProvider│
    │ Bridge  │ │ (歌词获取)    │
    └─────────┘ └──────────────┘
```

### 数据流

1. `SpotifyBridge` 每 500ms 轮询 Spotify → 发布播放状态变化
2. 歌曲切换时 → `LyricsProvider` 异步获取新歌词
3. `LyricsEngine` 结合播放进度 + 歌词时间轴 → 输出当前行
4. UI 层（悬浮窗 / 菜单栏）订阅当前行并渲染

## 模块设计

### SpotifyBridge

通过 AppleScript 轮询 Spotify 播放状态，输出结构化播放信息。

**数据模型：**

```swift
struct PlaybackState {
    let trackId: String
    let trackName: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let position: TimeInterval
    let isPlaying: Bool
}
```

**工作机制：**

- `Timer` 每 500ms 轮询，通过 AppleScript 读取 Spotify 状态
- 发布两种事件：`trackChanged`（歌曲切换）、`positionUpdated`（进度更新）
- 通过 `Combine` 的 `CurrentValueSubject` 发布状态

**AppleScript 脚本：**

```applescript
tell application "Spotify"
    set trackId to id of current track
    set trackName to name of current track
    set trackArtist to artist of current track
    set trackAlbum to album of current track
    set trackDuration to duration of current track
    set playerPosition to player position
    set playerState to player state as string
end tell
```

**边界处理：**

- Spotify 未运行 → 停止轮询，监听 `NSWorkspace` 应用启动通知后恢复
- Spotify 运行但未播放 → 保持轮询，标记 `isPlaying = false`
- 轮询失败 → 跳过本次，下次重试（不累积重试）

### LyricsProvider

根据歌曲名 + 歌手名从第三方 API 获取歌词，解析为带时间轴的结构化数据。

**数据模型：**

```swift
struct LyricsLine {
    let time: TimeInterval
    let text: String
}

struct Lyrics {
    let lines: [LyricsLine]
    let source: String
}
```

**Provider 协议：**

```swift
protocol LyricsProviding {
    func fetchLyrics(trackName: String, artist: String) async throws -> Lyrics
}
```

**MVP 歌词源 — LRCLIB：**

- API：`GET https://lrclib.net/api/get?artist_name={}&track_name={}`
- 返回 `syncedLyrics` 字段（LRC 格式）
- 免费、开源、无需 API Key

**LRC 解析：**

- 格式：`[mm:ss.xx] 歌词文本`
- 解析后按 `time` 升序排列
- 忽略空行和元数据标签（`[ti:]`、`[ar:]` 等）

**缓存：**

- 内存缓存，key 为 `"artist-trackName"`
- 避免重复网络请求
- MVP 不做磁盘持久化

**边界处理：**

- API 无结果 → 返回空歌词，UI 显示"暂无歌词"
- 返回纯文本歌词（无时间轴） → MVP 不显示
- 网络错误 → 抛出错误，Engine 层处理

### LyricsEngine

核心引擎，连接 SpotifyBridge 和 LyricsProvider，计算当前应显示的歌词行。

**输出模型：**

```swift
struct LyricsDisplay {
    let previous: String?
    let current: String
    let next: String?
    let progress: Double  // 当前行进度 0.0~1.0（逐字同步预留）
}
```

**当前行计算：**

- 二分查找：在已排序的 `lines` 中找到最后一个 `time <= currentPosition` 的行
- 只在 index 变化时才发布新的 `LyricsDisplay`（避免重复渲染）
- 播放暂停时停止计算，恢复时继续

**状态机：**

```swift
enum EngineState {
    case idle        // Spotify 未运行或未播放
    case loading     // 正在获取歌词
    case playing     // 歌词同步中
    case noLyrics    // 当前歌曲无歌词
    case error(String)
}
```

**发布：**

- `@Published var display: LyricsDisplay?`
- `@Published var state: EngineState`
- UI 通过 `ObservableObject` 订阅

### SettingsStore

用户设置持久化，使用 `UserDefaults` / `@AppStorage`。

**MVP 设置项：**

- 悬浮窗位置（x, y）
- 字体大小
- 悬浮窗显示/隐藏

**完整版新增：**

- 歌词风格（纯文字 / 胶囊）
- 歌词时间偏移
- 歌词源优先级
- 开机自启

## UI 层

### 悬浮窗

**技术：** `NSPanel` 子类 + `NSHostingView`（嵌入 SwiftUI）

**窗口属性：**

- `.floating` level — 始终在最上层
- `.nonactivatingPanel` — 不抢焦点
- `isOpaque = false` + `backgroundColor = .clear` — 透明背景
- `isMovableByWindowBackground = true` — 可拖拽
- `ignoresMouseEvents = true`（默认），按住 Option 切换为可拖拽

**MVP 歌词渲染（纯文字风格）：**

- 单行当前歌词，白色粗体
- 多层黑色阴影保证在任何壁纸上可读
- 默认位置：屏幕底部居中，Dock 上方
- 拖拽后记住位置

### 菜单栏

**NSStatusItem：**

- 图标：音符符号 `♫`（Spotify 未播放时）
- MVP：仅图标，点击弹出 Popover
- 完整版：图标 + 跑马灯歌词文本

**跑马灯实现（完整版）：**

- 自定义 `NSView` 作为 `statusItem.button` 内容
- `CABasicAnimation` 平移动画，固定宽度约 200pt
- 歌词行切换时重置动画

**Popover：**

- MVP：显示/隐藏悬浮窗开关、退出应用
- 完整版：歌曲信息（封面、歌名、歌手）、歌词预览、完整设置

## 项目结构

```
Lyricist/
├── Lyricist.xcodeproj
├── Lyricist/
│   ├── App/
│   │   ├── LyricistApp.swift
│   │   └── AppDelegate.swift
│   ├── Bridge/
│   │   └── SpotifyBridge.swift
│   ├── Lyrics/
│   │   ├── LyricsProviding.swift
│   │   ├── LRCLIBProvider.swift
│   │   ├── LRCParser.swift
│   │   └── LyricsCache.swift
│   ├── Engine/
│   │   └── LyricsEngine.swift
│   ├── UI/
│   │   ├── FloatingPanel.swift
│   │   ├── FloatingLyricsView.swift
│   │   ├── MenuBarController.swift
│   │   └── PopoverView.swift
│   ├── Settings/
│   │   └── SettingsStore.swift
│   └── Models/
│       ├── PlaybackState.swift
│       ├── LyricsLine.swift
│       └── LyricsDisplay.swift
└── LyricistTests/
    ├── LRCParserTests.swift
    ├── LyricsEngineTests.swift
    └── SpotifyBridgeTests.swift
```

## 技术选择

| 项 | 选择 | 原因 |
|---|------|------|
| UI 框架 | SwiftUI + AppKit 混合 | SwiftUI 高效开发 UI，AppKit 补齐悬浮窗系统级能力 |
| 最低系统版本 | macOS 13 (Ventura) | SwiftUI 成熟度 + 用户覆盖率平衡 |
| Swift 版本 | 5.9+ | async/await、Observation |
| 网络层 | 原生 URLSession | 请求简单，无需第三方库 |
| 数据流 | Combine + ObservableObject | 适配 SwiftUI 订阅 |
| 持久化 | UserDefaults / @AppStorage | 配置项少且简单 |
| 外部依赖 | 无 | 全部用系统 API 实现 |
| 沙盒 | 关闭 | AppleScript 需要无沙盒权限 |

## App 配置

- `LSUIElement = true` — 纯菜单栏应用，不显示 Dock 图标
- `NSAppleEventsUsageDescription` — AppleScript 权限说明
- Development 签名，不上架 App Store（因无沙盒）
- 分发方式：GitHub Release 或 Homebrew Cask
