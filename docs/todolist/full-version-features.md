# 完整版功能待办清单

> 对照设计文档 `specs/2026-04-06-lyricist-design.md` 整理
> MVP 已完成，以下为完整版剩余功能

## 当前状态（超出 MVP 已实现）

- ✅ 多歌词源 fallback（LRCLIB → 网易云）
- ✅ 歌词时间偏移微调
- ✅ 繁体转简体

---

## 功能待办

### UI — 悬浮窗风格

#### TODO-UI-1：胶囊气泡风格

设计文档中列为完整版必备风格之一。

- 悬浮窗背景：磨砂玻璃（`NSVisualEffectView`，`.hudWindow` 材质）或纯色圆角矩形
- 内边距 + 圆角（约 12pt radius）
- 歌词文字颜色适配深色/浅色背景
- 与当前「纯文字无背景」风格并列，可在设置中切换

#### TODO-UI-2：悬浮窗风格切换

- 在 `SettingsStore` 新增 `overlayStyle: OverlayStyle`（enum：`.plain` / `.capsule`）
- `FloatingLyricsView` 根据 style 渲染不同外观
- `PopoverView` 设置面板中增加风格选择器

---

### UI — 菜单栏

#### TODO-UI-3：菜单栏跑马灯歌词

设计文档中的实现方案：
- 自定义 `NSView` 替换 `NSStatusItem.button` 的默认内容
- 固定宽度约 200pt，超出部分用 `CABasicAnimation` 横向平移
- 歌词行切换时重置动画，播放暂停时停止动画
- 图标 `♫` 保留在跑马灯左侧

---

### UI — Popover 扩展

#### TODO-UI-4：Popover 显示歌曲信息

当前 `PopoverView` 只有显隐切换和退出按钮，完整版应补充：

- 专辑封面（需从 Spotify 获取图片 URL，或用 `SpotifyBridge` 扩展 AppleScript 读取 `artwork url`）
- 当前歌名 + 歌手名
- 当前歌词行预览（前 3 行）

#### TODO-UI-5：Popover 完整设置面板

- 字体大小滑块（已有 `SettingsStore.fontSize`，但未在 UI 中暴露）
- 悬浮窗风格选择（配合 TODO-UI-2）
- 歌词源优先级排序（配合 TODO-PROVIDER-1）
- 时间偏移微调（已有逻辑，确认 UI 入口完整）
- 开机自启开关（配合 TODO-SYSTEM-1）

---

### 歌词同步

#### TODO-LYRICS-1：逐字歌词同步（YRC）

设计文档中作为完整版核心功能，依赖网易云 YRC 格式：

- 解析 YRC 格式（JSON，每个字有独立时间戳）
- 新增 `LyricsWord` 模型：`{ time: TimeInterval, duration: TimeInterval, text: String }`
- `LyricsDisplay.progress` 字段（目前预留但未使用）改为驱动逐字高亮
- `FloatingLyricsView` 中当前行内按字逐步高亮或颜色渐变
- 依赖 TODO-NETEASE（netease-eapi-improvements.md）中的 EAPI 歌词接口，才能拿到 `yrc` 字段

---

### 歌词源

#### TODO-PROVIDER-1：歌词源优先级设置

- `SettingsStore` 新增 `providerOrder: [String]`（默认 `["lrclib", "netease"]`）
- `LyricsEngine` 按用户设置的顺序 fallback，而非硬编码
- Popover 设置面板中允许拖拽排序

#### TODO-PROVIDER-2：网易云 EAPI 接口改造

详见 `netease-eapi-improvements.md`，重点：
- 切换到 EAPI 端点解决境外 `-460` 问题
- 获取翻译歌词 `tlyric`

#### TODO-PROVIDER-3：翻译歌词显示

依赖 TODO-PROVIDER-2 的 `tlyric` 字段：
- `LyricsLine` 新增可选 `translation: String?`
- `FloatingLyricsView` 在当前行下方以较小字号显示翻译
- `SettingsStore` 新增 `showTranslation: Bool` 开关

---

### 系统集成

#### TODO-SYSTEM-1：开机自启

- 使用 `SMAppService.mainApp.register()` / `unregister()`（macOS 13+ API）
- `SettingsStore` 新增 `launchAtLogin: Bool`
- Popover 设置面板中增加对应开关

#### TODO-SYSTEM-2：专辑封面获取

为 TODO-UI-4 提供封面图片：
- 扩展 `SpotifyBridge` 的 AppleScript，读取 `artwork url of current track`
- 或通过 Spotify Web API（需 OAuth，复杂度高，暂缓）
- `PlaybackState` 新增 `artworkURL: URL?`

---

## 优先级建议

| 优先级 | 功能 | 原因 |
|---|---|---|
| 高 | TODO-PROVIDER-2（EAPI 接口） | 修复网易云境外失败，影响用户体验 |
| 高 | TODO-SYSTEM-1（开机自启） | 日常使用必备，实现简单 |
| 中 | TODO-UI-5（完整设置面板） | 字体大小等已有后端逻辑，补 UI 即可 |
| 中 | TODO-UI-1/2（胶囊风格） | 视觉差异化，设计文档重点功能 |
| 中 | TODO-UI-3（跑马灯） | 菜单栏体验提升 |
| 低 | TODO-LYRICS-1（逐字同步） | 依赖 EAPI，实现复杂 |
| 低 | TODO-PROVIDER-3（翻译歌词） | 依赖 EAPI，受众偏向中文用户 |
| 低 | TODO-UI-4（封面） | 体验锦上添花，实现有一定复杂度 |
