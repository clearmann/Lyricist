# 网易云音乐接口改进计划

> 参考项目：[Lyricify Lyrics Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper)

## 背景

当前 `NeteaseProvider.swift` 使用的是网易云旧版无加密接口（`/api/search/get`、`/api/song/lyric`），在境外 IP 或未登录状态下，该接口会返回 `-460` 错误，导致回退失败。Lyricify 的实现揭示了更可靠的 EAPI 方案。

---

## 现状对比

| 特性 | 当前 Lyricist | Lyricify 参考实现 |
|---|---|---|
| 搜索接口 | `/api/search/get`（旧，无加密） | `/api/search/get/web` + EAPI 双路回退 |
| 歌词接口 | `/api/song/lyric`（旧，无加密） | `weapi/song/lyric` + EAPI 新接口 |
| 加密方式 | 无 | weapi：AES-CBC + RSA；EAPI：AES-ECB |
| 逐字歌词 | 不支持 | 支持 YRC 格式 |
| 翻译歌词 | 不获取 | 获取 `tlyric`（翻译）、`romalrc`（罗马音） |
| 错误处理 | 无 `-460` 处理 | 检测到 `-460` 后自动切换 EAPI |
| 搜索匹配 | 简单字符串包含 | 艺人名模糊匹配 + 时长评分 + 歌名相似度 |

---

## 待办事项

### 优先级高 — 修复境外访问失败问题

#### TODO-1：切换搜索到 EAPI 端点

- **端点**：`https://interface.music.163.com/eapi/cloudsearch/pc`
- **方法**：POST，表单参数 `params`（AES-ECB 加密后的 hex 字符串）
- **加密 key**：`e82ckenh8dichen8`（AES-ECB，无 IV）
- **加密逻辑**：
  ```
  url_path = "/eapi/cloudsearch/pc"
  body = { "s": keyword, "type": "1", "limit": "30", "offset": "0", "total": "true" }
  body["header"] = { "os": "android", "appver": "8.0.0", ... }
  message = "nobody{url_path}use{json(body)}md5forencrypt"
  digest = md5(message).hexLower
  data = "{url_path}-36cd479b6b5-{json(body)}-36cd479b6b5-{digest}"
  params = aesECBEncrypt(data, key).hexUpper
  POST params=params
  ```
- **回退策略**：先尝试旧接口，收到 `-460` 时切换 EAPI；或直接默认用 EAPI

#### TODO-2：切换歌词获取到 EAPI 端点

- **端点**：`https://interface3.music.163.com/eapi/song/lyric/v1`
- **方法**：POST，同上加密方式
- **请求参数**：`{ "id": songId, "cp": "false", "lv": "0", "kv": "0", "tv": "0", "rv": "0", "yv": "0", "ytv": "0", "yrv": "0" }`
- **响应字段**：`lrc`（标准 LRC）、`tlyric`（翻译）、`romalrc`（罗马音）、`yrc`（逐字）
- **最低目标**：解析 `lrc.lyric` 字段（与当前行为一致，但走更可靠的接口）

---

### 优先级中 — 功能增强

#### TODO-3：获取并显示翻译歌词

- EAPI 歌词响应中包含 `tlyric.lyric` 字段（LRC 格式的中文翻译）
- 显示方案：在当前歌词行下方以较小字号叠加翻译行
- 需修改 `LyricsDisplay` 模型，增加可选的 `translation` 字段
- 需修改 `FloatingLyricsView` 支持双行显示

#### TODO-4：改进搜索匹配算法

当前仅做简单 `contains` 匹配，建议增加：
- **时长匹配**：Spotify `playbackState` 已有 `duration`，可与搜索结果的 `duration` 字段做差值评分（Lyricify 的 `DurationMatch`）
- **艺人名归一化**：处理 `&`、`feat.`、`、`等分隔符，拆分后逐一匹配（Lyricify 的 `ArtistMatch`）
- **歌名降噪**：去除 `(Remastered)`、`(Live)`、`[Official Audio]` 等后缀再匹配

---

### 优先级低 — 扩展数据源

#### TODO-5：添加 QQ 音乐作为第三回退

- 支持 QRC 格式（逐字，高质量）
- 需要 Cookie/Token，API 较复杂，可参考 Lyricify 的 `QQMusic/Api.cs`

#### TODO-6：添加酷狗音乐作为第四回退

- 支持 KRC 格式（加密，需 XOR 解密 + zlib 解压）
- 中文歌曲覆盖率高，补充网易云未收录的歌曲

---

## 参考资料

- Lyricify EAPI 加密实现：[EapiHelper.cs](https://github.com/WXRIW/Lyricify-Lyrics-Helper/blob/master/Lyricify.Lyrics.Helper/Providers/Web/Netease/EapiHelper.cs)
- Lyricify 网易云 API：[Netease/Api.cs](https://github.com/WXRIW/Lyricify-Lyrics-Helper/blob/master/Lyricify.Lyrics.Helper/Providers/Web/Netease/Api.cs)
- Lyricify 网易云 Searcher：[NeteaseSearcher.cs](https://github.com/WXRIW/Lyricify-Lyrics-Helper/blob/master/Lyricify.Lyrics.Helper/Searchers/NeteaseSearcher.cs)
