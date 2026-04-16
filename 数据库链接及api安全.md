# StoryMe — 数据库连接及 API 安全文档

> **项目**: StoryMe (iOS 儿童 AI 绘本生成器)
> **后端方案**: Firebase Cloud Functions v2 (TypeScript)
> **AI 服务**: 火山引擎 / 豆包 (Volcengine Doubao)
> **更新日期**: 2026-04-15

---

## 目录

1. [整体架构](#1-整体架构)
2. [文件清单与职责](#2-文件清单与职责)
3. [API 密钥安全机制](#3-api-密钥安全机制)
4. [Cloud Function 详解](#4-cloud-function-详解)
5. [数据流转图](#5-数据流转图)
6. [本地验证方法](#6-本地验证方法)
7. [部署流程](#7-部署流程)
8. [安全检查清单](#8-安全检查清单)

---

## 1. 整体架构

### 核心思路：后端代理模式

iOS 客户端 **不再直接持有** 火山引擎 API Key，而是通过 Firebase Cloud Functions 作为安全代理转发请求。

```
┌──────────────┐         Firebase SDK (HTTPS)         ┌─────────────────────┐
│              │  ──────────────────────────────────►  │  Cloud Functions    │
│   iOS App    │    { childName, theme, style, ... }   │  (generateStory)    │
│  (StoryMe)   │                                       │                     │
│              │  ◄──────────────────────────────────  │  ┌───────────────┐  │
│  不含任何     │    { success, storyData }             │  │ 输入校验       │  │
│  API Key     │                                       │  │ 环境变量读取    │  │
└──────────────┘                                       │  │ Doubao API 调用│  │
                                                       │  │ 错误处理/日志  │  │
                                                       │  └───────┬───────┘  │
                                                       └──────────┼──────────┘
                                                                  │
                                                    Bearer Token  │
                                                    (服务端持有)    │
                                                                  ▼
                                                       ┌─────────────────────┐
                                                       │  火山引擎 Doubao API │
                                                       │  /chat/completions  │
                                                       └─────────────────────┘
```

### 为什么选择 Firebase Cloud Functions？

| 考量           | 说明                                                        |
|---------------|-------------------------------------------------------------|
| **iOS 集成**   | 项目已配置 `GoogleService-Info.plist`，iOS SDK 直接调用 `onCall` |
| **零运维**     | Serverless，无需管理服务器、负载均衡                            |
| **安全**       | API Key 仅存在于服务端环境变量，客户端永远拿不到                   |
| **成本**       | 免费额度足够 MVP 阶段使用                                      |
| **区域就近**   | 部署至 `asia-northeast1`（东京），靠近目标用户                    |

---

## 2. 文件清单与职责

### 新增文件

| 文件路径                      | 职责说明                                      |
|-----------------------------|----------------------------------------------|
| `firebase.json`             | Firebase 项目配置，指定 functions 源码目录为 `functions/` |
| `functions/.env`            | 环境变量文件，存放 `VOLCENGINE_API_KEY`（占位符）       |
| `functions/package.json`    | Node.js 项目清单，声明依赖和脚本命令                    |
| `functions/tsconfig.json`   | TypeScript 编译器配置（ES2022, CommonJS, strict）     |
| `functions/src/index.ts`    | **核心文件** — `generateStory` Cloud Function 实现     |
| `functions/lib/index.js`    | TypeScript 编译产物（自动生成，已 gitignore）            |

### 修改文件

| 文件路径         | 修改内容                                                              |
|-----------------|----------------------------------------------------------------------|
| `.gitignore`    | 新增三行：`functions/.env`、`functions/lib/`、`functions/node_modules/` |

### 文件结构总览

```
test1/
├── firebase.json                  ← Firebase 项目配置
├── .gitignore                     ← 已添加 functions 相关忽略规则
├── GoogleService-Info.plist       ← iOS Firebase 配置（已有）
│
├── functions/
│   ├── .env                       ← API 密钥（不提交 Git）
│   ├── package.json               ← 依赖：firebase-functions v5, firebase-admin v12
│   ├── tsconfig.json              ← TypeScript 配置
│   ├── node_modules/              ← 依赖包（不提交 Git）
│   ├── src/
│   │   └── index.ts               ← generateStory 函数源码
│   └── lib/
│       ├── index.js               ← 编译产物（不提交 Git）
│       └── index.js.map
│
├── Models/                        ← iOS 数据模型
├── ViewModels/                    ← iOS 视图模型
├── Services/
│   ├── AIService.swift            ← iOS 端 AI 服务（当前直连，后续改为调用 Cloud Function）
│   └── ImageStorageService.swift  ← 本地图片存储服务
└── Views/                         ← SwiftUI 视图
```

---

## 3. API 密钥安全机制

### 旧方案（不安全）

```
iOS App ──[硬编码 API Key]──► 火山引擎 API
```

- API Key 存储在 `Secrets.xcconfig`，编译进 App 二进制包
- 任何人反编译 IPA 即可提取密钥
- 密钥泄露 → 配额被盗用，产生费用

### 新方案（安全）

```
iOS App ──[无密钥]──► Cloud Function ──[Bearer Token]──► 火山引擎 API
```

**三层保护**：

| 层级 | 机制 | 说明 |
|-----|------|------|
| **存储层** | `functions/.env` | 密钥仅存在于服务端文件，已加入 `.gitignore` |
| **运行时** | `process.env.VOLCENGINE_API_KEY` | Node.js 进程环境变量，外部无法访问 |
| **传输层** | Firebase SDK 内置 HTTPS | 客户端与 Cloud Function 之间全程加密 |

### `.env` 文件内容

```env
VOLCENGINE_API_KEY=your_api_key_here
```

> 部署前必须将 `your_api_key_here` 替换为真实密钥。

### `.gitignore` 相关条目

```gitignore
# Firebase Functions
functions/.env            ← 防止密钥提交到 Git
functions/lib/            ← 编译产物
functions/node_modules/   ← 依赖包
```

---

## 4. Cloud Function 详解

### 函数签名

```typescript
export const generateStory = onCall(
  { region: "asia-northeast1" },
  async (request) => { ... }
);
```

- **类型**: Firebase v2 `onCall` HTTPS 函数
- **名称**: `generateStory`
- **区域**: `asia-northeast1`（东京）

### 输入参数 (`request.data`)

| 字段             | 类型     | 必填 | 说明                 |
|-----------------|----------|------|---------------------|
| `childName`     | `string` | 是   | 儿童主角名字          |
| `theme`         | `string` | 是   | 故事主题              |
| `style`         | `string` | 是   | 风格（温馨/冒险/奇幻） |
| `pageCount`     | `number` | 是   | 页数（1-12）          |
| `childAppearance` | `string` | 否 | 主角外貌描述（来自照片分析）|

### 处理流程

```
1. 输入校验
   ├── 必填字段缺失 → HttpsError("invalid-argument")
   └── pageCount 范围 → 必须 1-12

2. 密钥读取
   ├── process.env.VOLCENGINE_API_KEY
   └── 未配置 → HttpsError("failed-precondition")

3. Prompt 构建
   ├── System Prompt: 儿童绘本作家角色设定，要求纯 JSON 输出
   └── User Prompt:   包含 childName/theme/style/pageCount/appearance

4. API 调用
   ├── POST https://ark.cn-beijing.volces.com/api/v3/chat/completions
   ├── Header: Authorization: Bearer <API_KEY>
   ├── Body: { model, messages, max_tokens: 4000 }
   ├── 网络异常 → HttpsError("unavailable")
   └── 非 200  → HttpsError("internal")

5. 响应提取
   ├── 解析 JSON → choices[0].message.content
   ├── 内容为空 → HttpsError("internal")
   └── 成功 → return { success: true, storyData: content }
```

### 返回值

```json
{
  "success": true,
  "storyData": "[{\"pageNumber\":1,\"text\":\"...\",\"imageDescription\":\"...\",\"emoji\":\"star.fill\"}]"
}
```

### 错误处理

| 场景           | HttpsError Code         | 客户端提示                          | 服务端日志 |
|---------------|------------------------|------------------------------------|---------:|
| 缺少必填参数   | `invalid-argument`     | Missing required fields...          | 无       |
| pageCount 越界 | `invalid-argument`     | pageCount must be 1-12              | 无       |
| 密钥未配置     | `failed-precondition`  | Server AI key is not configured     | `logger.error` |
| 网络不可达     | `unavailable`          | Failed to reach AI service          | `logger.error` |
| API 返回非 200 | `internal`             | AI service returned HTTP {status}   | `logger.error` + 响应体 |
| 响应解析失败   | `internal`             | Invalid response from AI service    | `logger.error` |
| 内容为空       | `internal`             | AI returned empty content           | `logger.error` |

---

## 5. 数据流转图

### iOS 客户端调用方式（未来集成）

```swift
// Swift — 使用 Firebase Functions SDK
import FirebaseFunctions

let functions = Functions.functions(region: "asia-northeast1")
let callable = functions.httpsCallable("generateStory")

let result = try await callable.call([
    "childName": "Emma",
    "theme": "Be Brave",
    "style": "Warm & Cozy",
    "pageCount": 6,
    "childAppearance": "A girl with curly brown hair..."
])

let data = result.data as? [String: Any]
let storyJSON = data?["storyData"] as? String
// 解析 storyJSON 为 [StoryPage] 数组...
```

### 完整请求链路

```
iOS App
  │
  │  Firebase SDK (HTTPS, 自动认证)
  ▼
Cloud Function (asia-northeast1)
  │
  │  1. 校验 request.data
  │  2. 读取 process.env.VOLCENGINE_API_KEY
  │  3. 构建 system + user prompt
  │
  │  fetch POST (HTTPS)
  │  Authorization: Bearer <key>
  ▼
Volcengine Doubao API
  │
  │  choices[0].message.content
  ▼
Cloud Function
  │
  │  { success: true, storyData: "..." }
  ▼
iOS App
  │
  │  解析 JSON → [StoryPage]
  ▼
渲染故事绘本 UI
```

---

## 6. 本地验证方法

### 6.1 TypeScript 类型检查（无需密钥）

```bash
cd functions
npx tsc --noEmit
# 无输出 = 无错误
```

### 6.2 编译构建

```bash
cd functions
npx tsc
ls lib/
# 预期输出: index.js  index.js.map
```

### 6.3 Firebase 本地模拟器测试

```bash
# 1. 先将 .env 中的 API Key 替换为真实值
# 2. 启动模拟器
cd functions
npm run serve

# 3. 模拟器会输出本地 URL，例如:
#    http://127.0.0.1:5001/storyme/asia-northeast1/generateStory
```

### 6.4 验证 .env 是否被 Git 忽略

```bash
git check-ignore functions/.env
# 预期输出: functions/.env
```

### 6.5 验证依赖安装

```bash
cd functions
npm ls firebase-functions firebase-admin
# 应显示 firebase-functions@5.x.x 和 firebase-admin@12.x.x
```

---

## 7. 部署流程

### 前置条件

1. 已安装 Firebase CLI：`npm install -g firebase-tools`
2. 已登录：`firebase login`
3. 已关联项目：`firebase use <your-project-id>`
4. 已将 `functions/.env` 中的密钥替换为真实值

### 部署命令

```bash
cd functions
npm run deploy
# 等同于: firebase deploy --only functions
```

### 部署后验证

```bash
# 查看函数日志
firebase functions:log --only generateStory

# 确认函数已部署
firebase functions:list
```

### 生产环境密钥管理

对于正式部署，建议使用 Firebase Secret Manager 代替 `.env`：

```bash
# 设置密钥（加密存储在 Google Cloud）
firebase functions:secrets:set VOLCENGINE_API_KEY

# 在 index.ts 中声明（可选，v2 自动从 process.env 读取）
export const generateStory = onCall(
  { region: "asia-northeast1", secrets: ["VOLCENGINE_API_KEY"] },
  async (request) => { ... }
);
```

---

## 8. 安全检查清单

### 已完成

- [x] API Key 从客户端代码移至服务端环境变量
- [x] `functions/.env` 已加入 `.gitignore`
- [x] `functions/lib/` 和 `functions/node_modules/` 已加入 `.gitignore`
- [x] Cloud Function 包含输入参数校验
- [x] 所有 API 错误通过 `firebase-functions/logger` 记录
- [x] 错误信息不向客户端泄露内部细节（无 stack trace、无密钥片段）
- [x] TypeScript strict 模式已开启
- [x] pageCount 范围校验（1-12）防止滥用

### 待完成（后续迭代）

- [ ] 集成 Firebase Authentication（仅认证用户可调用）
- [ ] 添加 Rate Limiting（防止单用户刷量）
- [ ] 添加用量配额（每用户每日 N 次生成上限）
- [ ] 将 iOS `AIService.swift` 改为调用 Cloud Function 而非直连 Doubao
- [ ] 移除 `Secrets.xcconfig` 中的 Doubao API Key
- [ ] 生产部署时改用 Firebase Secret Manager
- [ ] 添加 App Check（Device Attestation，防非法客户端调用）

---

## 附录：关键配置文件内容速查

### `firebase.json`

```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": ["node_modules", ".git", "firebase-debug.log", "firebase-debug.*.log", "*.local"]
    }
  ]
}
```

### `functions/package.json`（依赖版本）

| 依赖                      | 版本     | 用途                    |
|--------------------------|---------|------------------------|
| `firebase-functions`     | ^5.0.0  | Cloud Functions v2 SDK |
| `firebase-admin`         | ^12.0.0 | Firebase Admin SDK      |
| `typescript`             | ^5.4.0  | TypeScript 编译器       |

### `functions/tsconfig.json`（关键配置）

| 选项               | 值          | 说明               |
|-------------------|-------------|-------------------|
| `target`          | `es2022`    | 支持 top-level await 和原生 fetch |
| `module`          | `commonjs`  | Firebase Functions 要求           |
| `strict`          | `true`      | 严格类型检查                       |
| `outDir`          | `lib`       | 编译输出目录                       |
