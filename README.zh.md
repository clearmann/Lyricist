# Lyricist

中文 | [English](README.md)

**Spotify 桌面悬浮歌词**

Lyricist 是一个轻量级 macOS 菜单栏应用，实时读取 Spotify 播放状态，将同步歌词以透明悬浮窗的形式显示在桌面最上层——始终可见，从不碍事。

---

## 功能特性

- **桌面最上层悬浮** — 歌词浮在所有窗口之上，跨所有 Space，全屏应用中同样显示
- **逐行歌词同步** — 当前行平滑切换，动画过渡自然流畅
- **双歌词源兜底** — 优先从 [LRCLIB](https://lrclib.net) 获取，失败自动回落到网易云音乐，覆盖更广
- **繁体转简体** — 中文歌词自动转换，无需手动设置
- **时间偏移微调** — 歌词感觉超前或滞后时，滑动调节即可对齐
- **纯菜单栏应用** — 无 Dock 图标，不打扰，安静常驻状态栏
- **可拖拽 · 位置记忆** — 按住 Option 拖动悬浮窗到任意位置，下次启动自动恢复
- **零外部依赖** — 全部基于系统框架实现

## 系统要求

- macOS 13 Ventura 及以上
- Spotify 桌面客户端
- Apple Silicon (arm64)

> Lyricist 通过 AppleScript 读取 Spotify 播放信息，首次启动时 macOS 会弹窗请求「自动操作」权限，允许即可。

## 安装

从 [Releases](../../releases) 页面下载最新版本。

1. 打开 `.dmg`，将 **Lyricist.app** 拖入 `/Applications`
2. 启动应用 — 菜单栏出现音符图标 `♩`
3. 在 Spotify 中播放音乐，歌词随即显示在桌面上

> 由于 Lyricist 在 App Store 之外分发且使用 ad-hoc 签名，首次打开时 macOS 可能提示无法验证开发者。右键点击应用 → **打开** 即可绕过。

## 使用说明

| 操作 | 方法 |
|------|------|
| 显示 / 隐藏悬浮歌词 | 点击菜单栏 `♩` → 开关切换 |
| 移动悬浮窗位置 | 按住 **Option** 拖拽 |
| 调整歌词时间偏移 | 点击 `♩` → 时间偏移滑块 |
| 退出应用 | 点击 `♩` → 退出 |

## 从源码构建

需要 Xcode 16 或 Swift 5.9+。

```bash
git clone https://github.com/clearmann/Lyricist.git
cd Lyricist

# 调试构建
swift build -c debug

# 运行测试
swift test

# 发布构建
swift build -c release
```

编译产物在 `.build/release/Lyricist`。若需要完整的 `.app` 包（含 AppleScript 权限），参考 release 工作流中的打包步骤。

## 工作原理

```
Spotify  ──AppleScript──►  SpotifyBridge  ──trackChanged──►  LyricsEngine
（每 500ms 轮询）                                                    │
                                                        LRCLIB / 网易云 API
                                                                    │
                                             LyricsDisplay（上一行 / 当前行 / 下一行）
                                                    │
                                         FloatingPanel（NSPanel .floating 层级）
                                         菜单栏 Popover
```

`SpotifyBridge` 每 500ms 通过 AppleScript 轮询 Spotify。歌曲切换时，`LyricsEngine` 异步获取并缓存歌词，之后用二分查找在已排序的时间戳列表中实时定位当前行。透明 `NSPanel` 不抢焦点，自动加入所有 Space。

## License

MIT
