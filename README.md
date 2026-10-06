# StoryMe

为 3–6 岁孩子生成个性化绘本的 iOS App。上传孩子的照片，AI 写出故事并画出插图，孩子成为故事的主角。

## 架构

```
iOS App (SwiftUI)
    │  只调 Firebase 可调用函数，不持有任何 API Key
    ▼
Firebase Cloud Functions (TypeScript, asia-northeast1)
    │  generateStory / generateImage / analyzeAppearance
    ▼
火山引擎方舟（豆包）
    文本模型 → 故事   视觉模型 → 照片分析   文生图模型 → 插图
```

**所有 API Key 只存在于云函数的 `functions/.env`，iOS 端零密钥配置。** 想换别家的 AI 服务，只需改云函数，App 代码不用动。

绘本数据存在设备本地（`UserDefaults` + Documents 目录），不上云。

## 环境要求

只能在 **macOS** 上开发，因为需要 Xcode。

### 必须自己装的 4 样

| 装什么 | 版本 | 从哪装 | 为什么 |
|---|---|---|---|
| **Xcode** | 26.0+ | Mac App Store（约 10GB） | 编译 iOS App，自带 Swift、模拟器、`xcodebuild` |
| **iOS 模拟器运行时** | iOS 17.0+ | Xcode → Settings → Components | Xcode 16 起不再预装，要单独下载（数 GB） |
| **Node.js** | 20（18+ 可用） | [nodejs.org](https://nodejs.org) 或 `brew install node@20` | 跑云函数和 Firebase 模拟器 |
| **Java (JDK)** | 11+ | `brew install openjdk` 或 [adoptium.net](https://adoptium.net) | **Firestore 模拟器是 Java 写的**，没装它 `emulators:start` 会失败 |

Java 这条最容易漏：它不是给 iOS 用的，是 Firebase 的 Firestore 和 Auth 模拟器本身跑在 JVM 上。

### 不用单独装的

| | 说明 |
|---|---|
| Git | macOS 自带（或装了 Xcode 就有） |
| `firebase-tools` | 已在 `functions/package.json` 的 devDependencies 里，`npm install` 会装好；文中的 `npx firebase` 用的就是它 |
| TypeScript | 同上，`npm install` 带 |
| Firebase SDK (Swift) | Xcode 通过 SPM 自动下载，版本锁在 `Package.resolved`（12.19.2） |
| Firebase CLI 全局安装 | 不需要，用 `npx` 即可 |
| 手动添加 Firebase 包 | **不需要**，声明已随工程提交，见下方第 4 步 |

### 还需要两个账号

| 账号 | 费用 | 用来做什么 |
|---|---|---|
| Firebase（Google 账号即可） | 免费额度够用 | 建项目、拿 `GoogleService-Info.plist` |
| 火山引擎方舟 | **按量付费，要实名认证和充值** | 豆包的文本 / 视觉 / 文生图模型 |

火山引擎这条是真正的门槛——需要实名认证，而且文生图按张收费。

### 不需要的

- **不需要 Apple 开发者账号**（$99/年）。工程里 `DEVELOPMENT_TEAM` 是空的，在**模拟器**上跑不需要签名。只有想装到真机才需要 Apple ID 配个免费的个人团队。
- **不需要真机**。而且真机反而跑不通——Debug 下连的是 `127.0.0.1` 的本机模拟器，手机访问不到你 Mac 的 localhost。

### 磁盘占用预估

```
Xcode + iOS 运行时        ~25 GB
functions/node_modules    ~366 MB
Firebase Swift SDK 缓存   ~1 GB
```

## 安装

### 1. 建自己的 Firebase 项目

App 必须连你自己的 Firebase 项目，本仓库不包含任何可共用的凭据。

1. 打开 [console.firebase.google.com](https://console.firebase.google.com)，创建项目
2. 添加 iOS 应用，**Bundle ID 填 `com.storyme.app`**（要和工程里的 `PRODUCT_BUNDLE_IDENTIFIER` 一致，否则 Firebase 拒绝）
3. 下载 `GoogleService-Info.plist`，拖进 Xcode 项目根目录
   - 弹窗里勾选 **Copy items if needed** 和 **Add to targets: StoryMe**
   - 必须通过 Xcode 拖拽，光放进文件夹不会被打包，运行时 `FirebaseApp.configure()` 会抛异常崩溃
4. 控制台里启用 **Authentication**，登录方式勾选 **电子邮件/密码**

> 不需要启用 Firestore。依赖虽然链接了，但目前没有任何业务代码读写云端 Firestore，绘本数据全在设备本地。

该文件已被 `.gitignore` 忽略，不会误传。

### 2. 改项目 ID

`.firebaserc` 里写的是原作者的项目，改成你自己的：

```json
{ "projects": { "default": "你的-firebase-项目-id" } }
```

### 3. 配置火山引擎密钥

```bash
cd functions
npm install
cp .env.example .env
```

编辑 `.env`，填入 [火山方舟控制台](https://console.volcengine.com/ark) 的 API Key 和推理接入点 ID。

接入点在**在线推理 → 自定义推理接入点**创建，ID 形如 `ep-20260409191516-m6xw9`。**状态必须是「运行中」**，显示「已停止」时调用会返回 `InvalidEndpoint.ClosedEndpoint`，表现为 App 里的 "Failed to generate story"。

推荐模型：文本和视觉用 Doubao-Seed 系列（支持多模态，两个变量可填同一个接入点），文生图用 Doubao-Seedream 系列。

三个 `ep-` 接入点 ID **没有默认值**，留空会直接报 `Server config missing: DOUBAO_xxx_MODEL_ID`。`DOUBAO_IMAGE_API_KEY` 是唯一可以留空的，留空时回落到 `VOLCENGINE_API_KEY`。

### 4. 等 Firebase SDK 下载完

**不需要手动添加 Firebase 包。** 依赖声明已经随工程提交了：`project.pbxproj` 里有包引用、6 个产品和 Frameworks 链接阶段，版本锁在 `Package.resolved`。

打开 `StoryMe.xcodeproj` 后 Xcode 会自动开始下载解析，窗口顶部有进度。**第一次要 1–5 分钟**，Firebase 连带 13 个传递依赖（gRPC、abseil、leveldb、GoogleUtilities 等）一共约 1GB，别以为卡死了。

> ⚠️ 不要去 **File → Add Package Dependencies** 再加一遍 —— 会产生重复的 package reference。

如果 Xcode 没自动解析，或者报 `Unable to find module dependency: 'FirebaseCore'`，在终端手动触发：

```bash
xcodebuild -resolvePackageDependencies -project StoryMe.xcodeproj
```

跑完应该出现 `resolved source packages: ... Firebase ...`。这一步锁定的 6 个产品是：

```
FirebaseAuth   FirebaseCore   FirebaseCrashlytics
FirebaseFirestore   FirebaseFunctions   FirebaseStorage
```

### 5. 启动模拟器并运行

Debug 构建连的是**本机 Firebase 模拟器**，不是云端。先开模拟器：

```bash
# 在仓库根目录
npx firebase emulators:start --import=functions/saved_data --export-on-exit=functions/saved_data
```

看到 `All emulators ready!` 后，这个终端窗口保持开着。

| 端口 | 用途 |
|---|---|
| 5001 | Functions —— App 的 AI 调用走这里 |
| 9099 | Auth |
| 8080 | Firestore |
| 4000 | 模拟器 Web 控制台（给你看日志用，App 不连它） |

然后在 Xcode 里 ⌘R。控制台应打出：

```
[Firebase] Emulators configured — Auth:9099, Functions:5001, Firestore:8080
```

### 6. 第一次进 App：先注册一个账号

Debug 下登录走的是**本机 Auth 模拟器**，里面一开始是空的，没有任何账号。在登录页点 **Sign Up** 注册即可：

- 不需要真实邮箱，`test@test.com` 这类就行
- 密码至少 6 位

账号存在 `functions/saved_data/`，按 Ctrl+C 正常退出模拟器时会导出保存，下次 `--import` 带回来。强杀终端则丢失。

### 7. 打开插图开关

**Debug 构建默认跳过插图生成**（`AppConfig.skipImageGeneration` 在 Debug 下默认 `true`，为了省 token）。所以第一次生成出来的绘本只有文字、没有图，这是预期行为，不是故障。

要看插图，去 **Profile → DEVELOPER → Skip Illustrations (Dev)** 把开关**关掉**。Release 构建永远生成插图，不受这个开关影响。

生成失败时，去 <http://127.0.0.1:4000> → Functions → Logs 看云函数返回的真实错误。App 界面上只显示笼统的失败提示。

## 开发

改完云函数要重新编译，模拟器才会用上新代码：

```bash
cd functions && npm run build
```

改完 `functions/.env` 必须重启模拟器——环境变量只在启动时读一次。

部署到线上：

```bash
firebase deploy --only functions
```

云函数固定在 `asia-northeast1`，与 `AIService.swift` 里的区域设置对应。改区域要同时改两处。

## 目录结构

```
ContentView.swift          根视图 + 路由表（AppScreen 枚举 → 各页面）
StoryMeApp.swift           入口 + Firebase 初始化 + 模拟器配置
Models/                    Story, StoryPage, StoryTemplate, GrowthBook
ViewModels/                Story, Photo, Auth, Settings, GrowthBook
Views/                     各页面与组件
Services/
  AIService.swift          调用云函数的唯一出口
  ImageStorageService.swift 插图落盘到 Documents 目录
  AppConfig.swift          开发期开关
functions/src/index.ts     云函数：generateStory / generateImage / analyzeAppearance
```

## 费用提示

生成一本绘本会调用一次文本模型加若干次文生图，文生图是主要成本。**Debug 下默认跳过插图**以省 token，开关在 **Profile → DEVELOPER → Skip Illustrations (Dev)**（仅 Debug 可见）。Release 构建永远生成插图。页数在故事设置页可调 1–12，页数越多插图越多。
