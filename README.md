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

| | 版本 |
|---|---|
| Xcode | 26.0+ |
| iOS | 17.0+ |
| Swift | 5.9 |
| Node.js | 20 |
| Firebase SDK | 12.19.2（自动解析） |

还需要：Firebase 账号（免费额度够用）、火山引擎方舟账号（按量付费）。

## 安装

### 1. 建自己的 Firebase 项目

App 必须连你自己的 Firebase 项目，本仓库不包含任何可共用的凭据。

1. 打开 [console.firebase.google.com](https://console.firebase.google.com)，创建项目
2. 添加 iOS 应用，**Bundle ID 填 `com.storyme.app`**（要和工程里的 `PRODUCT_BUNDLE_IDENTIFIER` 一致，否则 Firebase 拒绝）
3. 下载 `GoogleService-Info.plist`，拖进 Xcode 项目根目录
   - 弹窗里勾选 **Copy items if needed** 和 **Add to targets: StoryMe**
   - 必须通过 Xcode 拖拽，光放进文件夹不会被打包，运行时 `FirebaseApp.configure()` 会抛异常崩溃
4. 控制台里启用 **Authentication**（邮箱/密码登录方式）和 **Firestore**

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

### 4. 加 Firebase SDK 依赖

在 Xcode 里：**File → Add Package Dependencies…**，粘贴

```
https://github.com/firebase/firebase-ios-sdk
```

只勾这 6 个产品，`Add to Target` 设为 `StoryMe`：

```
FirebaseAuth   FirebaseCore   FirebaseCrashlytics
FirebaseFirestore   FirebaseFunctions   FirebaseStorage
```

第一次解析要几分钟。命令行等价操作：

```bash
xcodebuild -resolvePackageDependencies -project StoryMe.xcodeproj
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

生成一本绘本会调用一次文本模型加若干次文生图，文生图是主要成本。调试时可在 **Profile → Developer → Skip Illustrations (Dev)** 打开跳过插图的开关（仅 Debug 构建可见）。
