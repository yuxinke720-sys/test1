# StoryMe 现状梳理（大改前快照）

> 时间：2026-09-27　分支：`APIandDatabase`　最近提交：`ebea71b`（另有未提交改动，见文末）
> 规模：Swift 约 5,400 行（27 个文件）＋ 云函数 `functions/src/index.ts` 392 行

---

## 1. 一句话概括

SwiftUI 做的 AI 儿童绘本 App：用户用邮箱登录，上传孩子照片，选主题，经 Firebase 云函数调用**豆包**生成故事文字和插图。**所有绘本都只存在手机本地**，云端只负责登录和 AI 调用。

---

## 2. 页面与跳转

**没有用 NavigationStack，也没有用 TabView。** 全靠一个枚举 `AppScreen`（[ContentView.swift](ContentView.swift) 第 3–17 行）加一个大 `switch` 切换页面。每个页面都拿到 `currentScreen` 的绑定，给它赋值就算跳转。当前页面记在 `@AppStorage("lastScreen")` 里，重启后会回到上次的页面。

**启动顺序：** 没看过引导 → `OnboardingView`；没登录 → `LoginView`；否则进入主界面。

| 页面 | 文件 | 说明 |
|---|---|---|
| 首页 | Views/HomeView.swift (590 行) | 最大的文件；有崩溃测试按钮和 3 本假样书 |
| 上传照片 | Views/PhotoUploadView.swift | 调用"分析长相" |
| 故事设置 | Views/StorySetupView.swift | 选主题、风格、页数 |
| 生成中 | Views/LoadingView.swift | **在这里真正发起生成** |
| 阅读器 | Views/StorybookView.swift | 退出时才保存 |
| 分享 | Views/ShareView.swift | 分享面板没做完 |
| 我的书 | Views/MyBooksView.swift | |
| 日历 | Views/StoryCalendarView.swift | |
| 模板库 / 模板预览 / 模板传照片 | Views/StoryTemplateView.swift、TemplatePreviewView.swift、TemplatePhotoUploadView.swift | |
| 个人页 | Views/ProfileView.swift + SettingsRow.swift | 大量写死的文字和不能点的按钮 |
| AI 测试 | ContentView.swift 里的 `AITestView` | 开发用，**正式版也会显示** |

底部标签栏是 [TabBarView.swift](Views/TabBarView.swift) 里的 `smTabBar()` 函数，有 5 个标签：Home / Templates / My Books / **AI Test** / Profile。每个页面各自画一遍。

**自由创作流程：** 首页 → 传照片（分析长相）→ 设置 → 生成中 → 阅读器 → 分享/返回
**模板流程：** 模板库 → 预览 → 传照片 → 生成中 → 阅读器

---

## 3. 四个 ViewModel

全部在 `ContentView` 里创建，再一层层手动往下传（没用 environmentObject）。

| ViewModel | 负责 |
|---|---|
| AuthViewModel | 登录、注册、退出，监听 Firebase 登录状态 |
| StoryViewModel (356 行) | 核心：生成参数、生成进度、当前阅读、书架（`savedStories`）、日历数据、本地存取 |
| PhotoViewModel | 选照片（最多 10 张）、调用长相分析 |
| SettingsViewModel | 个人页的几个开关；只有"深色模式"和"跳过插图"真正起作用 |

孩子名字写死为 `"Emma"`（StoryViewModel 第 8 行），界面上没有地方可以修改。

---

## 4. 数据存在哪

| 数据 | 位置 | 是否上云 |
|---|---|---|
| 绘本文字、收藏、阅读时间 | UserDefaults，键名 `savedStories_<用户ID>`，整个数组编码成 JSON 存一条 | ❌ |
| 插图 | 手机 `Documents/users/<用户ID>/stories/<书ID>/page_N.jpg` | ❌ |
| 上次读到哪 | UserDefaults `lastStoryID_<ID>`、`lastPage_<ID>` | ❌ |
| 设置、上次页面 | UserDefaults（所有账号共用） | ❌ |
| 账号 | Firebase Auth | ✅ |

- **Firestore 和 Firebase Storage 都已经链接进工程，但代码里一次都没用过。**
- `firestore.rules` 是测试模式，已在 2026-06-14 过期，现在拒绝一切读写。

---

## 5. AI 生成链路

```
App (AIService.swift)  →  Firebase 云函数 (asia-northeast1)  →  豆包 (火山引擎 ark.cn-beijing)
```

| 云函数 | 作用 | 模型 |
|---|---|---|
| `analyzeAppearance` | 看照片（最多 3 张），总结孩子长相，不超过 80 词 | 豆包视觉模型 |
| `generateStory` | 生成 `{title, pages[{text, imageDescription, emoji}]}` | 豆包文字模型 |
| `generateImage` | 每页画一张图，带参考照片 | 豆包画图模型 |

- 密钥在 `functions/.env`（没有进 git）。
- **Debug 模式连本机模拟器**（`127.0.0.1:5001`，登录走 `9099`），见 [StoryMeApp.swift](StoryMeApp.swift) 第 14–19 行。需要先在终端启动 `npx firebase-tools emulators:start`，而且**真机上连不上**。
- **跳过插图开关**：`AppConfig.skipImageGeneration`（[Services/AppConfig.swift](Services/AppConfig.swift)）。Debug 下由个人页 DEVELOPER 区的开关控制，默认跳过；Release 下永远画图。
- 插图是 12 张同时并发请求；某页失败就静默没图，只打印一行日志。
- App 端把所有错误都归成 `apiError`，服务端返回的具体错误信息丢失了。
- 模板流程**不做长相分析**，也**不用模板自带的文字**，页数用的是上次设置的值（默认 1）。
- `generateMockStory`（假故事生成器）从来没被调用过。

---

## 6. 已知 Bug（大改时顺手修）

1. **日历每天只能显示一本**：`storyDays` 返回 `[日: Story]`，同一天多本时后面的覆盖前面的。首页的"N stories"其实数的是天数。
2. **生成完不会自动保存**：只有退出阅读器或点分享时才保存。在阅读器里 App 被杀掉，故事就丢了，插图变成孤儿文件。
3. **样书会被存进用户书架**：打开首页或我的书里的假样书，退出时会调用 `saveStory()`。
4. **"最近阅读"时间会被抹掉**：`markAsRead` 只改了 `savedStories`，没改 `currentStory`；退出时 `saveStory()` 又用旧的 `currentStory` 把它覆盖回去。
5. **重启恢复到阅读器基本失效**：恢复时登录还没完成，书架是空的，只能退回首页。
6. **翻页就重写全部数据**：每次翻页都把整个书架重新编码写进 UserDefaults，书多了会卡。
7. 我的书页永远显示样书，"空书架"状态永远不会出现。

---

## 7. 安全与上线风险

- ⚠️ **云函数不检查登录（没有 `request.auth`）、没有 App Check、没有限流**：任何人拿到地址都能刷你的豆包额度。**上线前必须修。**
- 云函数日志会打印包含孩子长相的完整提示词（涉及儿童隐私）。
- 照片页写着"不存储、会删除"，但照片实际发给了火山引擎，这些承诺没有经过核实。引导页的隐私政策也没有链接。
- 正式版里还有 **AI Test 标签**和**首页崩溃测试按钮**（`fatalError`）。
- 调试日志被提交进了 git：`firebase-debug.log`（510KB）、`functions/firebase-debug.log`（3.9MB）。
- `GoogleService-Info.plist` 在仓库里（Firebase 客户端通常允许这样，但要在后台限制 API Key 的使用范围）。

---

## 8. 废代码、写死的内容、半成品

- **写死的文字**：个人页的 "Emma's Mom"、"Age 2"、"Free Plan"、"v1.0.0"。
- **点了没反应的按钮**：个人页的 Add child / Story Preferences / Language / Rate / Privacy / Help；阅读器的 Redo；分享页的分享面板；"Save to Camera Roll" 实际只是保存到书架。
- **没用上的东西**：Crashlytics 链接了但没 import；首页的 `holidayDecoIcon`；AIService 里几个从未使用的错误类型。
- **过时的文件**：
  - `project.yml`（XcodeGen）已经过时，**不要用它重新生成工程**，否则会丢掉 Firebase 依赖。
  - `Secrets.xcconfig` 里是旧的豆包密钥，已经没有代码引用。
  - `claude.md`、`旧claude.md`、`数据库链接及api安全.md` 的内容都和现状对不上。

---

## 9. 大改建议优先级（供参考）

1. **先提交当前改动**，建一个干净的起点（见下方清单），日志和 `saved_data` 不要提交。
2. **数据上云**：`Story` 存 Firestore，插图存 Storage，同时写好 rules。这能一并解决"换设备看不到"、"UserDefaults 太慢"和"没自动保存"三个问题。
3. **云函数加 `request.auth` 校验和 App Check**。
4. **导航改成 NavigationStack + TabView**，拆分 HomeView 和 ContentView。
5. **孩子资料做成真实数据**（名字、年龄、长相描述存下来复用），替换写死的 "Emma"。
6. 修掉第 6 节的 bug；把 AI Test 标签和崩溃按钮放进 `#if DEBUG`。
7. 更新 `claude.md`，删掉 `旧claude.md` 和 `project.yml`。

---

## 附：当前未提交改动

**已修改：** ContentView、StoryMeApp、ProfileView（新增 DEVELOPER 区，故事数改为真实数量）、AIService（跳过插图改读 AppConfig）、Services/AppConfig.swift（改成 Debug 开关）、SettingsViewModel、project.pbxproj（加入 OnboardingView）、firebase.json
**已删除：** 根目录多余的 AppConfig.swift
**新增未跟踪：** OnboardingView、SettingsRow、SettingsViewModel、firestore.rules、firestore.indexes.json
**不应提交：** functions/saved_data/、*.log、.DS_Store、.agents/、.claude/

工程备份：`~/Downloads/yxkapp/project.pbxproj.bak`（在加入 OnboardingView 之前备份）
