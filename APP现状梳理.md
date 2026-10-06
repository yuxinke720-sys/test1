

## 3. 页面与跳转

**没有用 NavigationStack，也没有用 TabView。** 全靠枚举 `AppScreen`（[ContentView.swift](ContentView.swift) 第 3–21 行）加一个大 `switch` 切换。每个页面拿到 `currentScreen` 的绑定，赋值就算跳转。当前页面记在 `@AppStorage("lastScreen")`，重启回到上次页面。

**启动顺序：** 没看过引导 → `OnboardingView`；没登录 → `LoginView`；否则进主界面。

| 页面 | 文件 | 说明 |
|---|---|---|
| 首页 | Views/HomeView.swift (569 行) | 最大的文件；有 3 本假样书 |
| 创作中心 | Views/CreateHubView.swift (430 行) | 自由创作 / 成长册入口 |
| 社区 | Views/CommunityView.swift | |
| 上传照片 | Views/PhotoUploadView.swift | 调用长相分析 |
| 故事设置 | Views/StorySetupView.swift | 主题、风格、页数（± 步进器，1–12 页） |
| 生成中 | Views/LoadingView.swift | **在这里真正发起生成** |
| 阅读器 | Views/StorybookView.swift | 退出时才保存 |
| 分享 | Views/ShareView.swift | 分享面板没做完 |
| 我的书 | Views/MyBooksView.swift | |
| 日历 | Views/StoryCalendarView.swift (438 行) | |
| 模板库 / 预览 / 传照片 | StoryTemplateView、TemplatePreviewView、TemplatePhotoUploadView | |
| 成长册 | GrowthBookDetailView (551 行)、GrowthBookPageView、GrowthBookReaderView、CompletionCeremonyView | |
| 个人页 | Views/ProfileView.swift + SettingsRow.swift | |
| **孩子档案** | **Views/ChildProfileView.swift** | **新增：姓名 / 性别 / 生日** |

底部标签栏是 [TabBarView.swift](Views/TabBarView.swift) 的 `smTabBar()`，5 个标签：**Home / Create / Community / My Books / Profile**。

> 上一版文档写的是 Home / Templates / My Books / **AI Test** / Profile。`AITestView` 在所有分支都不存在、`project.pbxproj` 里登记数为 0，是写了一半没保存的开发页；它的 4 处引用已删除，标签栏也不再有它。

**自由创作：** 首页/创作中心 → 传照片（分析长相）→ 设置 → 生成中 → 阅读器 → 分享/返回
**模板流程：** 模板库 → 预览 → 传照片 → 生成中 → 阅读器

---

## 4. 六个 ViewModel

全部在 `ContentView` 里创建，再手动往下传（没用 environmentObject）。

| ViewModel | 负责 |
|---|---|
| AuthViewModel | 登录、注册、退出，监听 Firebase 登录状态 |
| StoryViewModel | 核心：生成参数、进度、当前阅读、书架（`savedStories`）、日历数据、本地存取 |
| PhotoViewModel | 选照片（最多 10 张），**真实调用** `AIService.analyzeChildAppearance` |
| GrowthBookViewModel | 成长册的创建、章节、配图、导出 |
| SettingsViewModel | 个人页开关；只有"深色模式"和"跳过插图"真正起作用 |
| **ChildProfileViewModel** | **新增：孩子档案，按 uid 存 UserDefaults** |

**孩子名字不再写死。** 上一版文档里 `StoryViewModel.childName = "Emma"` 且界面上无处可改。现在 `ChildProfileView` 是唯一编辑入口，`ContentView.syncChildName()` 监听整个 `child` 对象变化同步过去。

**档案信息真的进了 prompt。** `Child.promptDescriptor` 生成类似 `"Emma is a 4-year-old girl; refer to Emma as she"` 的句子，与照片分析出的外貌描述合并后作为 `childAppearance` 送进云函数——云函数把它当自由文本拼进提示词（`index.ts:60`），所以不需要改云端。性别选"Prefer not to say"时用 `they`。

---

## 5. 数据存在哪

| 数据 | 位置 | 是否上云 |
|---|---|---|
| 绘本文字、收藏、阅读时间 | UserDefaults，键 `savedStories_<uid>`，整个数组编码成一条 JSON | ❌ |
| 插图 | `Documents/users/<uid>/stories/<书ID>/page_N.jpg` | ❌ |
| **孩子档案** | **UserDefaults，键 `childProfile_<uid>`** | ❌ |
| 成长册 | `Documents/users/<uid>/growth/books.json` + 同目录图片 | ❌ |
| 上次读到哪 | UserDefaults `lastStoryID_<uid>`、`lastPage_<uid>` | ❌ |
| 设置、上次页面 | UserDefaults（所有账号共用） | ❌ |
| 账号 | Firebase Auth（Debug 下是本机模拟器） | ✅ |

- **Firestore 和 Firebase Storage 仍然一次都没用于业务数据。** 唯一出现 `Firestore.firestore()` 的地方是 `StoryMeApp.swift:20`，只为把它指向模拟器。
- `firestore.rules` 是测试模式，`allow read, write: if request.time < timestamp.date(2026, 6, 14)` —— **已过期，现在拒绝一切读写**。因为没有业务代码用 Firestore，暂时不影响功能。
- **换设备就看不到任何数据。** uid 只用于隔离同一台设备上的不同账号，不是云端标识。删除 App 即永久丢失，没有任何备份。

---

## 6. AI 生成链路

```
App (AIService.swift)  →  Firebase 云函数 (asia-northeast1)  →  豆包 (ark.cn-beijing.volces.com)
```

| 云函数 | 作用 | 模型 |
|---|---|---|
| `analyzeAppearance` | 看照片（最多 3 张），总结孩子长相，不超过 80 词 | 豆包视觉模型 |
| `generateStory` | 生成 `{title, pages[{text, imageDescription, emoji}]}` | 豆包文字模型 |
| `generateImage` | 每页画一张图，带参考照片 | 豆包画图模型 |

- 密钥在 `functions/.env`（已 gitignore，另有 `.env.example` 模板入库）。三个 `ep-` 接入点 ID 没有默认值，未配置时 `requireEnv()` 直接抛 `Server config missing`；`DOUBAO_IMAGE_API_KEY` 留空会回落到 `VOLCENGINE_API_KEY`。
- 接口是 **OpenAI 兼容格式**（`/chat/completions`、`messages`、`choices[0].message.content`），所以换到别家 OpenAI 兼容的服务只需改 URL 和模型 ID。
- **Debug 下三个服务全部指向本机模拟器**：Auth 9099、Functions 5001、**Firestore 8080（新增）**，见 [StoryMeApp.swift](StoryMeApp.swift)。Firestore 另外设成 `MemoryCacheSettings()`，避免模拟器数据落进生产磁盘缓存。真机上连不上。
- 需要先启动 `npx firebase emulators:start --import=functions/saved_data --export-on-exit=functions/saved_data`。
- **跳过插图开关**：`AppConfig.skipImageGeneration`，Debug 下由个人页 DEVELOPER 区控制，**默认跳过**（新人第一次生成会只有文字没有图，容易误判为故障，README 已写明）；Release 永远画图。
- 插图并发请求；某页失败就静默没图，只打印一行日志。
- App 端把所有错误归成 `apiError`，服务端具体错误信息丢失。
- 模板流程**不做长相分析**，也**不用模板自带文字**。
- `generateMockStory`（AIService.swift:362）仍然从未被调用。

---

## 7. 当前真正挡路的问题

**火山引擎接入点 `ep-20260409191516-m6xw9` 状态是「已停止」。** 调用返回 `InvalidEndpoint.ClosedEndpoint`，表现为 App 里的 "Failed to generate story"。这是从 09-27 至今一直没解决的原始问题，**代码侧已全部就绪，只差去火山方舟控制台启用接入点或新建一个把 ID 填进 `.env`**。

---

## 8. 已知 Bug（均已复核仍存在）

1. **日历每天只能显示一本**：`storyDays` 返回 `[Int: Story]`（StoryViewModel:193），同一天多本时后者覆盖前者。首页的"N stories"其实数的是天数。
2. **生成完不会自动保存**：全项目 4 处调 `saveStory()`，都在退出阅读器或点分享时。在阅读器里 App 被杀，故事丢失，插图变孤儿文件。
3. **样书会被存进用户书架**：打开首页或我的书里的假样书，退出时会 `saveStory()`。
4. **"最近阅读"时间会被抹掉**：`markAsRead` 只改 `savedStories` 不改 `currentStory`，退出时 `saveStory()` 用旧的 `currentStory` 覆盖回去。
5. **重启恢复到阅读器基本失效**：恢复时登录还没完成，书架是空的，只能退回首页。
6. **翻页就重写全部数据**：每次翻页把整个书架重新编码写进 UserDefaults。
7. 我的书页永远显示样书，"空书架"状态永远不会出现。
8. **档案未填时仍用占位名 "Emma"**：`syncChildName()` 只在名字非空时覆盖，`StoryViewModel.childName` 的默认值还是 `"Emma"`。需要首次启动强制引导填档案。
9. **孩子档案只支持一个孩子**：界面上 MY CHILDREN 是复数、有 Add 按钮，底层是单个 `Child`。做多孩子要改成数组 + 当前选中项，并按孩子隔离绘本数据。

---

## 9. 安全与上线风险

- ⚠️ **云函数仍然不检查登录**：`functions/src/index.ts` 里没有任何 `request.auth` 或 App Check 校验，也没有限流。任何人拿到地址就能刷你的豆包额度。**上线前必须修。**
- 云函数日志会打印包含孩子长相的完整提示词（儿童隐私）。
- 照片页写着"不存储、会删除"，但照片实际发给了火山引擎，承诺未经核实。引导页的隐私政策没有链接。
- **仓库是公开的**（`visibility: public`）。已确认 `functions/.env` 从未被提交；`GoogleService-Info.plist` 现已加入 `.gitignore`，但它在 `APIandDatabase` 分支的历史里存在且已推送到远端——需要在 Firebase 后台限制 API Key 使用范围。
- `firestore.rules` 已过期（2026-06-14）。
- ✅ 已修复：首页崩溃测试按钮（`fatalError`）已不存在；AI Test 标签已移除；被跟踪的调试日志已全部清出仓库（`git ls-files` 中无 `*.log`）。

---

## 10. 废代码与过时文件

- **写死的文字**：个人页的 "Free Plan"、"v1.0.0"。（"Emma's Mom" 和 "Age 2" 已改为读孩子档案）
- **点了没反应的按钮**：个人页的 Story Preferences / Language / Rate / Privacy / Help；阅读器的 Redo；分享页的分享面板；"Save to Camera Roll" 实际只存到书架。
- **没用上的东西**：Crashlytics 链接了但没 import；`generateMockStory`；AIService 里几个从未使用的错误类型。
- **过时文件**：
  - `project.yml`（XcodeGen）**已严重过时且仍在仓库里**：写着 `xcodeVersion: "15.0"`，没有任何 Firebase 包声明。谁执行 `xcodegen generate` 就会覆盖 `project.pbxproj`，把刚修好的 SPM 依赖和 Frameworks 阶段全部清掉，退回编译不过。建议删除或补齐。
  - `claude.md`（agent 指令文件）内容还写着 Gemini 架构和 `Secrets.xcconfig` 放 `GEMINI_API_KEY`，与现状完全不符。已从仓库移除、加入 `.gitignore`，文件仍在本地，**待更新**。
  - `Secrets.xcconfig` 还在硬盘上（未入库），里面是旧的豆包密钥，**已无任何代码或工程配置引用**，可以删。
  - `HANDOFF.md`（上一段会话的交接草稿）含测试账号 uid、模拟器 ID、本机代理端口，已从仓库移除并加入 `.gitignore`。
  - 上一版提到的 `旧claude.md`、`数据库链接及api安全.md` 已不存在。

---

## 11. 下一步优先级

1. **启用火山接入点**，让生成真正跑通（第 7 节）。
2. **云函数加 `request.auth` 校验和 App Check** —— 公开仓库 + 无校验的云函数是当前最大风险。
3. **更新 `firestore.rules`**，别留着一个过期的测试模式规则。
4. **处理 `project.yml`**：补齐 Firebase 依赖，或直接删掉避免误用。
5. **更新本地 `claude.md`** 为豆包 + 云函数架构（已不入库，但 agent 会读它）。
6. **数据上云**：`Story` 存 Firestore、插图存 Storage。这能一并解决"换设备看不到"、"UserDefaults 太慢"、"没自动保存"三个问题。依赖已经链接好，一行没用。
7. 修第 8 节的 bug；首次启动引导填孩子档案，去掉 "Emma" 占位。
8. **导航改成 NavigationStack + TabView**，拆分 HomeView 和 ContentView。
9. 孩子档案扩展成多孩子。

---

## 附：仓库与协作状态

**工作区干净**，`main` 与 `origin/main` 一致（`b6451e2`）。

**别人克隆后需要改 3 个地方**（详见 [README.md](README.md)）：

| 位置 | 做什么 |
|---|---|
| `functions/.env` | 从 `.env.example` 复制，填火山引擎 key 和接入点 |
| `GoogleService-Info.plist` | 下载自己 Firebase 项目的，用 Xcode 拖进项目 |
| `.firebaserc` | 项目 ID 改成自己的 |

Swift 代码一行不用改，iOS 端零密钥。`Package.resolved` 已入库，依赖版本锁定在 Firebase 12.19.2。

**仓库里对外可见的文档只有两份**：[README.md](README.md)（安装说明）和本文件。`HANDOFF.md`、`claude.md` 已移出仓库。

**不入库的本地文件**：`functions/.env`、`GoogleService-Info.plist`、`Secrets.xcconfig`、`functions/node_modules`、`functions/lib`、`functions/saved_data`、各类日志、`.DS_Store`、Xcode 用户态、`.claude/`、`.agents/`。
