# 交接：StoryMe 开发上下文（来自 VS Code 里的上一段 Claude Code 对话，2026-10-05）

请先读这份文件，再读 `CLAUDE.md` 和 `APP现状梳理.md`，然后等我的下一步指令。回复我时请用中文、讲大白话。

## 项目
- 路径：`~/Downloads/yxkapp/test1`。SwiftUI 写的 iOS App，做 AI 儿童绘本。分支 `APIandDatabase`，HEAD 是 `ebea71b`。**有大量未提交改动，还没 commit，也没 push。**
- 后端：Firebase（Auth 登录 + 3 个 Cloud Functions，代码在 `functions/src/index.ts`）→ 火山引擎豆包，负责写文字、看图、画图。
- Debug 版连的是本机 Firebase 模拟器：`127.0.0.1:5001` 云函数、`9099` 登录。启动命令（在项目根目录运行）：
  `cd functions && npm run build && cd .. && npx firebase-tools emulators:start --import=functions/saved_data --export-on-exit=functions/saved_data`
- 本机终端设置了代理 `http_proxy=127.0.0.1:7890`。用 curl 测本机地址时要加 `--noproxy '*'`，否则会被代理截走，返回 502。
- 模拟器：iPhone 17 Pro，ID 是 `F82522C5-CF79-4FAD-899E-35FA670BD3E6`。测试账号的 uid 是 `eKckPKcC2QMUoq2wKqcVlipl4BlT`。
- 命令行编译：
  `xcodebuild -project StoryMe.xcodeproj -scheme StoryMe -destination 'id=F82522C5-CF79-4FAD-899E-35FA670BD3E6' build`

## 已知阻塞
- **豆包写文字的接入点 `ep-20260409191516-m6xw9` 被关闭了**，火山引擎返回 `InvalidEndpoint.ClosedEndpoint`，所以现在生成故事会失败。要我去火山方舟控制台重新启用或充值。
- 画图接入点 `ep-20260409190549-2d5wv` 没测过。这些编号配置在 `functions/.env` 里。

## 这次对话做了什么（全部未提交）
1. **补上漏掉的工程文件**：把 `Views/OnboardingView.swift` 加进了 `project.pbxproj`（之前编译报错 "Cannot find 'OnboardingView'"）。**这个工程没有用文件夹自动同步，新建的 .swift 文件必须手动登记到 pbxproj。**
2. **整理"跳过插图"开关**：
   - 判断入口统一为 `Services/AppConfig.swift` 里的 `AppConfig.skipImageGeneration`。Debug 下读 UserDefaults 的 `devSkipImageGeneration`，**默认是跳过**；Release 下永远是 false，一定会画图。
   - 个人页的开关放在 DEVELOPER 区（只在 `#if DEBUG` 下显示），名字是 "Skip Illustrations (Dev)"。
   - 删掉了根目录多余的 `AppConfig.swift`。个人页的 "N stories created" 改成按实际数量显示。
3. **长期成长绘本模块（新功能）**：
   - 新增文件：
     - `Models/GrowthBook.swift`：GrowthBook、GrowthChapter、ChapterMedia、BookVisibility、GrowthScenario
     - `ViewModels/GrowthBookViewModel.swift`：数据存在 `Documents/users/<uid>/growth/books.json`，图片存在同目录下；**不用 UserDefaults，CLAUDE.md 有规定**
     - `Views/CreateHubView.swift`：Create 页，顶部有 Standard / Growth 两个选项卡，另外包含新建绘本的表单
     - `Views/GrowthBookDetailView.swift`：时间轴页，包含章节编辑器、照片选择、✨AI 插画、完结按钮
     - `Views/CompletionCeremonyView.swift`：完结动画
     - `Views/GrowthBookPageView.swift`：书页排版，App 内阅读和导出共用这一套
     - `Views/GrowthBookReaderView.swift`：翻页阅读，导出 PDF 和图片，调用系统分享面板
     - `Views/CoachMarkOverlay.swift`：高亮引导组件
     - `Views/CommunityView.swift`：社交"即将上线"占位页
   - 用户确认过的决定：
     - 数据先存本地，以后再迁到 Firestore 和 Storage。
     - "手绘页面"指 AI 根据照片生成插画。
     - 完结后**不调用 AI**，直接按章节排版成书，但要有完成动画增加仪式感。
     - 社交功能放到以后做，现在只在 App 里放个入口。
4. **导航调整**：
   - 新增 AppScreen：`create`、`community`、`growthBook`、`growthReader`。
   - 底部标签改为 Home · Create · Community · My Books · Profile。
   - 原来的 Templates 标签并进 Create 页；AI Test 移到个人页的 DEVELOPER 区。
   - 首页的 "Create Now" 现在进入 `.create`。
5. **新手引导**：
   - 开机引导改成 4 页，图标用 SF Symbols。原来的 emoji 在模拟器里显示成方块。
   - 第一次进 Create 页会弹 4 步高亮引导，由 `@AppStorage("hasSeenCreateGuide")` 控制。
   - 个人页新增 "Beginner Tutorial"，点了会重放两套引导。
6. **Debug 专用的启动参数**（截图验收用）：
   - `-debugOpenScreen <AppScreen 的 rawValue>`：直接打开某个页面
   - `-debugCelebrate YES`：直接播放完结动画
   - `-debugReaderPage N`：阅读器打开到第 N 页
   - `-debugExportPDF YES`：自动导出 PDF
   - `-hasSeenOnboarding NO` 和 `-hasSeenCreateGuide NO`：重放引导
7. **测试账号里加的演示数据**（只在模拟器本地）：
   - 7–9 月共 12 本普通绘本
   - 2 本长期绘本：进行中的《Emma Gets Dressed!》和已完结的《Emma's First Steps》
8. **两份文档**：`APP现状梳理.md` 是大改前的全量梳理，包括已知 bug、安全风险和废代码；本文件是交接说明。

## 备份
- `~/Downloads/yxkapp/project.pbxproj.bak`：加 OnboardingView 之前的工程文件
- `~/Downloads/yxkapp/project.pbxproj.before-growth.bak`：加长期绘本之前的工程文件

## 待办 / 下一步建议（按顺序）
1. **我**去火山引擎恢复豆包接入点，然后端到端测试：生成故事、长期绘本的 ✨ 插画。
2. 提交代码。⚠️ **commit 和 push 之前必须先问我。** 不要提交这些：`*.log`、`functions/saved_data/`、`.DS_Store`、`.agents/`、`.claude/`。建议把它们加进 `.gitignore`。
3. 画图模型：建议从当前接入点升级到 Seedream 5.0 Lite（单张约 0.22 元），完结封面用 5.0 Pro；海外版备选 Nano Banana 2。云函数里把模型做成环境变量，失败时自动换备用模型，图片并发数限制在 3–4。
4. 大改顺序：先把数据上云（Firestore + Storage + 安全规则）→ 云函数加 `request.auth` 校验和 App Check → 社交模块。
5. `APP现状梳理.md` 第 6 节列的 bug：日历每天只显示一本、生成完不会自动保存、样书会被存进书架、"最近阅读"时间被覆盖、重启无法恢复到阅读器。
6. 孩子名字写死成 "Emma"，要做成真实的孩子资料。

## 和我协作的习惯
- 用中文、大白话解释，少用术语。
- 改动前先确认方向；不可逆或对外的操作（push、删除数据、调用付费接口）先问我。
- 改完要编译验证，能截图就截图确认。
