# 🏗️ StoryMe Backend Architecture & Security Plan

> **Project**: StoryMe — AI-powered children's story generator (iOS, ages 3–6)
> **Current State**: Pure iOS app with hardcoded API keys, no backend, no auth
> **Goal**: Production-ready backend proxy that owns all LLM secrets and defends against abuse
> **Stack Recommendation**: TypeScript + Fastify + Prisma ORM + PostgreSQL + Redis
> **Date**: April 2026

---

## Table of Contents

1. [Overall Architecture](#1--overall-architecture-整体架构)
2. [Authentication & Data Security](#2--authentication--data-security-鉴权--数据安全)
3. [BOLA/IDOR Prevention](#3--bolaidor-prevention-防越权访问)
4. [SQL Injection Prevention](#4--sql-injection-prevention-防sql注入)
5. [Abuse & Quota Drainage Prevention](#5--abuse--quota-drainage-prevention-防薅羊毛)
6. [Database Schema Design](#6--database-schema-design)
7. [Deployment & Secrets Management](#7--deployment--secrets-management)
8. [Monitoring & Incident Response](#8--monitoring--incident-response)
9. [Security Checklist](#9--security-checklist)

---

## 1. 🏗️ Overall Architecture (整体架构)

### Why This Architecture?

StoryMe currently embeds Volcengine/Doubao API keys directly in `Secrets.xcconfig`, which is **committed to Git** and bundled into the app binary. Anyone with a jailbroken device or a simple binary dump can extract these keys and drain your API quota. The backend proxy pattern solves this completely — the iOS app never touches an LLM key.

### System Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PRODUCTION SYSTEM                               │
│                                                                         │
│  ┌──────────────┐     HTTPS        ┌──────────────────────────────────┐ │
│  │              │  ──────────────► │         BACKEND PROXY             │ │
│  │   iOS App    │  JWT + Device    │  ┌─────────┐  ┌───────────────┐  │ │
│  │  (StoryMe)   │  Attestation     │  │ Fastify │  │  Middleware    │  │ │
│  │              │ ◄────────────── │  │ Router  │→ │  Pipeline      │  │ │
│  │  - NO API    │   JSON/Stream    │  └────┬────┘  │  ┌───────────┐ │  │ │
│  │    keys      │                  │       │       │  │ Auth      │ │  │ │
│  │  - JWT only  │                  │       │       │  │ RateLimit │ │  │ │
│  │  - Device    │                  │       │       │  │ Quota     │ │  │ │
│  │    Attest    │                  │       │       │  │ Validate  │ │  │ │
│  └──────────────┘                  │       │       │  │ DevCheck  │ │  │ │
│                                    │       │       │  └───────────┘ │  │ │
│                                    │       ▼       └───────────────┘  │ │
│                                    │  ┌─────────┐                     │ │
│                                    │  │ Service  │                     │ │
│                                    │  │  Layer   │                     │ │
│                                    │  └────┬────┘                     │ │
│                                    └───────┼──────────────────────────┘ │
│                                            │                            │
│                     ┌──────────────────────┼──────────────────────┐     │
│                     │                      │                      │     │
│                     ▼                      ▼                      ▼     │
│              ┌────────────┐        ┌──────────────┐       ┌──────────┐ │
│              │ PostgreSQL │        │    Redis      │       │  LLM API │ │
│              │            │        │               │       │          │ │
│              │ - Users    │        │ - Rate limits │       │ Volcen-  │ │
│              │ - Stories  │        │ - Sessions    │       │ gine /   │ │
│              │ - Quotas   │        │ - Nonces      │       │ Doubao   │ │
│              │ - Devices  │        │ - Cache       │       │          │ │
│              └────────────┘        └──────────────┘       └──────────┘ │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    SECRETS (never in code)                        │   │
│  │  AWS Secrets Manager / Doppler / Infisical                       │   │
│  │  ├── DOUBAO_TEXT_API_KEY                                         │   │
│  │  ├── DOUBAO_IMAGE_API_KEY                                        │   │
│  │  ├── JWT_SIGNING_KEY (RS256 private key)                         │   │
│  │  ├── DATABASE_URL                                                │   │
│  │  └── REDIS_URL                                                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Why Fastify over Express?

| Criteria | Fastify | Express |
|----------|---------|---------|
| Performance | ~76k req/s (benchmark) | ~15k req/s |
| Schema validation | Built-in (JSON Schema) | Manual (add express-validator) |
| TypeScript | First-class support | Bolted on |
| Plugin system | Encapsulated, testable | Global middleware soup |
| Logging | Pino built-in (structured JSON) | Add morgan/winston |
| Streaming | Native support | Requires workarounds |

Fastify wins on every axis relevant to an API proxy. Express is fine too — the security patterns in this document apply to both.

### Why NOT Serverless (Lambda / Cloudflare Workers)?

For a **streaming LLM proxy**, serverless has real drawbacks:
- **Cold starts** add 200–800ms latency before the first token streams
- **Timeout limits** (Lambda: 15min, Workers: 30s CPU) conflict with long image generation (your current timeout is 120s)
- **Connection limits** — streaming SSE/WebSocket is awkward on Lambda
- **Cost** — at scale, always-on containers are cheaper than per-invocation billing for long-running LLM calls

**Recommendation**: Start with a containerized Fastify server on **Railway** or **Fly.io**. Migrate to ECS/EKS only if you need multi-region.

> ⚠️ **Common Mistake**: Building the backend as a "thin proxy" that just forwards requests. Your backend must be a **thick proxy** — it validates, rate-limits, quota-checks, and sanitizes BEFORE spending money on an LLM call. Every dollar of LLM cost that leaks through is your money, not the attacker's.

---

## 2. 🔐 Authentication & Data Security (鉴权 & 数据安全)

### Why Sign in with Apple?

StoryMe is a kids' app (ages 3–6). Apple requires apps in the Kids category to comply with strict privacy rules. Sign in with Apple is the cleanest path because:
- **No email collection by default** — Apple provides a relay email
- **No password to store** — reduces your liability surface
- **Required by App Store** if you offer any social login
- **Parents control the Apple ID** — aligns with COPPA

### Full Sign in with Apple Flow

```
┌─────────┐          ┌─────────┐         ┌─────────┐        ┌─────────┐
│  iOS    │          │ Apple   │         │ Your    │        │ Apple   │
│  App    │          │ Sign-In │         │ Backend │        │ ID      │
│         │          │ UI      │         │         │        │ Servers │
└────┬────┘          └────┬────┘         └────┬────┘        └────┬────┘
     │                    │                   │                   │
     │  1. User taps      │                   │                   │
     │  "Sign in with     │                   │                   │
     │   Apple" button    │                   │                   │
     │ ──────────────────►│                   │                   │
     │                    │                   │                   │
     │  2. Face ID /      │                   │                   │
     │  Touch ID prompt   │                   │                   │
     │ ◄──────────────────│                   │                   │
     │                    │                   │                   │
     │  3. User approves  │                   │                   │
     │ ──────────────────►│                   │                   │
     │                    │                   │                   │
     │  4. Apple returns: │                   │                   │
     │  - identityToken   │                   │                   │
     │    (JWT)           │                   │                   │
     │  - authCode        │                   │                   │
     │  - userIdentifier  │                   │                   │
     │ ◄──────────────────│                   │                   │
     │                    │                   │                   │
     │  5. POST /auth/apple                   │                   │
     │  { identityToken, authCode }           │                   │
     │ ──────────────────────────────────────►│                   │
     │                    │                   │                   │
     │                    │                   │  6. Fetch Apple's │
     │                    │                   │  public keys      │
     │                    │                   │  GET /auth/keys   │
     │                    │                   │ ─────────────────►│
     │                    │                   │                   │
     │                    │                   │  7. JWKS response │
     │                    │                   │ ◄─────────────────│
     │                    │                   │                   │
     │                    │                   │  8. Verify:       │
     │                    │                   │  - JWT signature  │
     │                    │                   │    (RS256)        │
     │                    │                   │  - iss ==         │
     │                    │                   │    appleid.apple  │
     │                    │                   │    .com           │
     │                    │                   │  - aud == your    │
     │                    │                   │    bundle ID      │
     │                    │                   │  - exp not passed │
     │                    │                   │                   │
     │                    │                   │  9. Upsert user   │
     │                    │                   │  in DB (apple_sub │
     │                    │                   │  as unique key)   │
     │                    │                   │                   │
     │                    │                   │  10. Issue YOUR   │
     │                    │                   │  JWT (access +    │
     │                    │                   │  refresh tokens)  │
     │                    │                   │                   │
     │  11. Return:       │                   │                   │
     │  { accessToken, refreshToken }         │                   │
     │ ◄──────────────────────────────────────│                   │
     │                    │                   │                   │
     │  12. Store tokens  │                   │                   │
     │  in iOS Keychain   │                   │                   │
     │  (NEVER UserDefaults!)                 │                   │
     ▼                    ▼                   ▼                   ▼
```

### JWT Token Strategy

```typescript
// Token issuance (backend)
import { SignJWT, jwtVerify } from 'jose';

// Access Token — short-lived, carried on every request
const accessToken = await new SignJWT({
  sub: user.id,           // Your internal user UUID
  aud: 'com.storyme.app', // Bundle ID
  scope: 'api',
})
  .setProtectedHeader({ alg: 'RS256', kid: keyId })
  .setIssuedAt()
  .setExpirationTime('15m')  // 15 minutes — short!
  .sign(privateKey);

// Refresh Token — long-lived, stored securely, used to get new access tokens
const refreshToken = await new SignJWT({
  sub: user.id,
  jti: crypto.randomUUID(), // Unique ID for revocation
  scope: 'refresh',
})
  .setProtectedHeader({ alg: 'RS256', kid: keyId })
  .setIssuedAt()
  .setExpirationTime('30d')
  .sign(privateKey);
```

**Why RS256 over HS256?**
- RS256 uses asymmetric keys (public/private pair)
- The backend signs with the private key; any service can verify with the public key
- If you ever add microservices, they can verify JWTs without sharing the secret
- Apple's own identity tokens use RS256 — consistency matters

### Token Refresh Flow

```
┌──────────┐                          ┌──────────┐
│ iOS App  │                          │ Backend  │
└─────┬────┘                          └─────┬────┘
      │                                     │
      │  API call with expired accessToken  │
      │ ───────────────────────────────────►│
      │                                     │
      │  401 Unauthorized                   │
      │ ◄───────────────────────────────────│
      │                                     │
      │  POST /auth/refresh                 │
      │  { refreshToken }                   │
      │ ───────────────────────────────────►│
      │                                     │
      │     Backend checks:                 │
      │     ✓ JWT signature valid           │
      │     ✓ jti not in revocation list    │
      │     ✓ Token not expired             │
      │     ✓ User still active in DB       │
      │                                     │
      │  { newAccessToken, newRefreshToken }│
      │ ◄───────────────────────────────────│
      │                                     │
      │  (Rotate: old refresh token is      │
      │   immediately revoked)              │
      ▼                                     ▼
```

**Refresh Token Rotation**: Every time a refresh token is used, issue a new one and revoke the old one. If an attacker steals a refresh token and the real user also uses it, one of them will present a revoked token — which triggers **immediate session kill** for that user, forcing re-authentication.

### What If a JWT Is Stolen?

| Scenario | Mitigation |
|----------|------------|
| Access token stolen | 15-minute expiry limits damage window. Attacker can make API calls but only briefly. |
| Refresh token stolen | Rotation detects reuse → both tokens revoked → user must re-auth via Apple |
| Both tokens stolen | Device attestation (Section 5) blocks requests from non-genuine devices |
| JWT signing key leaked | Rotate the RS256 key pair. All existing tokens become invalid. Users re-auth. |

### Chat History Encryption

StoryMe stores children's stories. This is sensitive data (children's content, potentially with appearance descriptions from photo analysis). Defense in depth:

```
┌─────────────────────────────────────────────┐
│           ENCRYPTION LAYERS                  │
│                                              │
│  Layer 1: Transport (HTTPS/TLS 1.3)         │
│  ├── All data encrypted in transit           │
│  └── Certificate pinning in iOS app          │
│                                              │
│  Layer 2: Database at Rest                   │
│  ├── PostgreSQL: full-disk encryption (AES)  │
│  └── Managed by cloud provider (e.g. RDS)    │
│                                              │
│  Layer 3: Field-Level Encryption (optional)  │
│  ├── story.pages[].text → AES-256-GCM       │
│  ├── story.childAppearance → AES-256-GCM    │
│  └── Key: derived from user's Apple sub +    │
│      server-side master key (envelope enc.)  │
│                                              │
│  Why field-level? If DB is dumped, stories   │
│  remain encrypted. Attacker needs both the   │
│  DB dump AND the key management service.     │
└─────────────────────────────────────────────┘
```

**COPPA Consideration**: Since StoryMe targets ages 3–6, you must minimize data collection. The `childAppearance` field from photo analysis is particularly sensitive — consider whether you even need to persist it, or if it should be ephemeral (used only during story generation, then discarded).

> ⚠️ **Common Mistake**: Storing JWTs in `UserDefaults` on iOS. Your current codebase uses `@AppStorage` (UserDefaults) extensively. JWTs MUST go in the iOS Keychain — `UserDefaults` is readable by anyone with physical device access or a backup extraction tool.

---

## 3. 🛡️ BOLA/IDOR Prevention (防越权访问)

### What Is BOLA? A Concrete Attack

BOLA (Broken Object-Level Authorization) is the **#1 API vulnerability** (OWASP API Top 10). Here's how it works against StoryMe:

```
ATTACK SCENARIO:
════════════════

Alice (User A) creates a story. It gets ID: story_abc123

1. Alice's app calls:
   GET /api/stories/story_abc123
   Authorization: Bearer <alice_token>
   → Returns Alice's story ✓

2. Attacker (User B) sees the pattern and tries:
   GET /api/stories/story_abc123
   Authorization: Bearer <attacker_token>

   If the backend only checks "is this a valid token?"
   but NOT "does this story belong to this user?"
   → Returns Alice's story to the attacker! 💀

   The attacker can now read stories about Alice's child,
   including appearance descriptions, names, and preferences.

3. Attacker iterates:
   GET /api/stories/story_abc124
   GET /api/stories/story_abc125
   ...
   → Mass scrapes all children's stories 💀💀💀
```

### Defense: Ownership-Scoped Middleware

The principle is simple: **every database query MUST be scoped to the authenticated user.** Never fetch by ID alone.

```typescript
// ❌ DANGEROUS — BOLA vulnerable
app.get('/api/stories/:id', async (req, reply) => {
  const story = await prisma.story.findUnique({
    where: { id: req.params.id }  // No user check!
  });
  return story;
});

// ✅ SAFE — ownership scoped
app.get('/api/stories/:id', async (req, reply) => {
  const story = await prisma.story.findUnique({
    where: {
      id: req.params.id,
      userId: req.user.id  // Compound filter: ID + ownership
    }
  });
  if (!story) {
    // Return 404, NOT 403 — don't leak that the resource exists
    return reply.code(404).send({ error: 'Story not found' });
  }
  return story;
});
```

### Middleware Pattern: Auto-Scoping

Create a Fastify plugin that injects the user scope into every request context:

```typescript
// src/plugins/ownership.ts
import { FastifyPluginAsync } from 'fastify';

const ownershipPlugin: FastifyPluginAsync = async (app) => {
  app.decorateRequest('scopedPrisma', null);

  app.addHook('preHandler', async (req) => {
    if (!req.user) return; // Skip for public routes

    // Create a scoped query helper
    req.scopedPrisma = {
      story: {
        findMany: (args: any = {}) =>
          prisma.story.findMany({
            ...args,
            where: { ...args.where, userId: req.user.id },
          }),
        findUnique: (args: any) =>
          prisma.story.findFirst({
            ...args,
            where: { ...args.where, userId: req.user.id },
          }),
        update: (args: any) =>
          prisma.story.updateMany({
            ...args,
            where: { ...args.where, userId: req.user.id },
          }),
        delete: (args: any) =>
          prisma.story.deleteMany({
            where: { ...args.where, userId: req.user.id },
          }),
      },
    };
  });
};
```

### Second Layer: PostgreSQL Row-Level Security (RLS)

Even if your application code has a bug, RLS at the database level prevents cross-user access:

```sql
-- Enable RLS on the stories table
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;

-- Force RLS even for table owners (important!)
ALTER TABLE stories FORCE ROW LEVEL SECURITY;

-- Policy: users can only see their own stories
CREATE POLICY user_stories_policy ON stories
  USING (user_id = current_setting('app.current_user_id')::uuid);

-- In your Prisma connection, set the user context before each query:
-- SET LOCAL app.current_user_id = '<user-uuid>';
-- (Use Prisma's $executeRaw in a transaction)
```

```
┌─────────────────────────────────────────────────────┐
│              BOLA DEFENSE IN DEPTH                   │
│                                                      │
│  Request                                             │
│    │                                                 │
│    ▼                                                 │
│  ┌─────────────────┐                                 │
│  │ Layer 1: Auth   │  "Who is this user?"            │
│  │ Middleware       │  Verify JWT, extract user.id    │
│  └────────┬────────┘                                 │
│           │                                          │
│           ▼                                          │
│  ┌─────────────────┐                                 │
│  │ Layer 2: App    │  "Add userId to every query"    │
│  │ Scoped Queries  │  where: { id, userId }          │
│  └────────┬────────┘                                 │
│           │                                          │
│           ▼                                          │
│  ┌─────────────────┐                                 │
│  │ Layer 3: DB     │  "Even if app forgets,          │
│  │ Row-Level       │   the DB itself blocks           │
│  │ Security        │   cross-user reads"              │
│  └────────┬────────┘                                 │
│           │                                          │
│           ▼                                          │
│  ┌─────────────────┐                                 │
│  │ Layer 4: Audit  │  "Log every resource access     │
│  │ Logging         │   for forensics"                │
│  └─────────────────┘                                 │
└─────────────────────────────────────────────────────┘
```

### BOLA Prevention Checklist

Every endpoint MUST satisfy ALL of the following before touching the database:

- [ ] JWT is verified and `req.user.id` is extracted
- [ ] The query includes `userId: req.user.id` in the WHERE clause
- [ ] If fetching by resource ID, use `findFirst` with compound filter (not `findUnique` by ID alone)
- [ ] Resource-not-found returns `404`, never `403` (don't leak existence)
- [ ] Bulk operations (list, delete-many) are auto-scoped via middleware
- [ ] No endpoint accepts `userId` as a request parameter (it always comes from the JWT)

> ⚠️ **Common Mistake**: Using sequential integer IDs for stories (`story/1`, `story/2`, `story/3`). This makes enumeration trivial. Use UUIDs (`story/a7b3c9d1-...`). UUIDs don't prevent BOLA, but they eliminate casual guessing.

---

## 4. 💉 SQL Injection Prevention (防SQL注入)

### How Prisma Eliminates SQL Injection

Prisma's query engine uses **parameterized queries** internally. Your TypeScript code writes structured objects, not SQL strings. The Prisma engine compiles these into safe, parameterized SQL that the database driver sends with bound parameters — injection is structurally impossible.

### Side-by-Side Comparison

```typescript
// ══════════════════════════════════════════════════════════════
// ❌ RAW SQL — DANGEROUS (SQL Injection vulnerable)
// ══════════════════════════════════════════════════════════════

app.get('/api/stories', async (req) => {
  const theme = req.query.theme; // User input: "adventure'; DROP TABLE stories;--"

  // This concatenates user input directly into SQL!
  const stories = await prisma.$queryRawUnsafe(
    `SELECT * FROM stories WHERE theme = '${theme}' AND user_id = '${req.user.id}'`
  );
  // Executed SQL:
  // SELECT * FROM stories WHERE theme = 'adventure'; DROP TABLE stories;--'
  // AND user_id = '...'
  //
  // Result: Your stories table is GONE 💀
});

// ══════════════════════════════════════════════════════════════
// ✅ PRISMA ORM — SAFE (parameterized automatically)
// ══════════════════════════════════════════════════════════════

app.get('/api/stories', async (req) => {
  const theme = req.query.theme; // Same malicious input

  const stories = await prisma.story.findMany({
    where: {
      theme: theme,        // Prisma sends this as a bound parameter
      userId: req.user.id, // Never concatenated into SQL
    },
  });
  // Prisma generates:
  // SELECT * FROM stories WHERE theme = $1 AND user_id = $2
  // Parameters: ["adventure'; DROP TABLE stories;--", "user-uuid"]
  //
  // The malicious string is treated as a literal value, not SQL code ✓
});

// ══════════════════════════════════════════════════════════════
// ⚠️ SAFE RAW QUERY — when you genuinely need raw SQL
// ══════════════════════════════════════════════════════════════

app.get('/api/stories/search', async (req) => {
  const searchTerm = req.query.q;

  // Use $queryRaw (NOT $queryRawUnsafe) with tagged template literals
  const stories = await prisma.$queryRaw`
    SELECT * FROM stories
    WHERE title ILIKE ${'%' + searchTerm + '%'}
    AND user_id = ${req.user.id}
  `;
  // Prisma's tagged template automatically parameterizes the values ✓
});
```

### Input Validation with Zod (BEFORE it hits the ORM)

Even though Prisma prevents SQL injection, you should validate inputs at the boundary. This catches bad data early, provides better error messages, and protects against other attack types (XSS, oversized payloads, type confusion).

```typescript
import { z } from 'zod';

// Define schemas for every endpoint's input
const GenerateStorySchema = z.object({
  childName: z.string()
    .min(1, 'Name is required')
    .max(50, 'Name too long')
    .regex(/^[\p{L}\p{N}\s'-]+$/u, 'Invalid characters in name'),

  theme: z.enum([
    'adventure', 'fantasy', 'animals',
    'space', 'ocean', 'dinosaurs',
  ]),

  style: z.enum(['warmCozy', 'adventure', 'fantasy']),

  pageCount: z.number()
    .int()
    .min(3, 'Minimum 3 pages')
    .max(12, 'Maximum 12 pages'),

  // Appearance from photo analysis — sanitize carefully
  childAppearance: z.string()
    .max(500)
    .optional(),

  // Prevent prompt injection in the story prompt
  customPrompt: z.string()
    .max(200)
    .regex(/^[\p{L}\p{N}\s,.!?'-]+$/u, 'Invalid characters')
    .optional(),
});

// Fastify plugin for Zod validation
app.post('/api/stories/generate', async (req, reply) => {
  const parseResult = GenerateStorySchema.safeParse(req.body);

  if (!parseResult.success) {
    return reply.code(400).send({
      error: 'Validation failed',
      details: parseResult.error.flatten().fieldErrors,
    });
  }

  // parseResult.data is now typed AND validated
  const { childName, theme, style, pageCount } = parseResult.data;
  // ... proceed to LLM call
});
```

### Prisma Raw Query Safety Rules

| Method | Safe? | When to Use |
|--------|-------|-------------|
| `prisma.model.findMany()` | ✅ Always safe | 99% of queries |
| `prisma.$queryRaw\`...\`` | ✅ Safe (tagged template) | Full-text search, complex JOINs |
| `prisma.$queryRawUnsafe()` | ❌ **DANGEROUS** | NEVER in production |
| `prisma.$executeRaw\`...\`` | ✅ Safe (tagged template) | Migrations, RLS setup |
| `prisma.$executeRawUnsafe()` | ❌ **DANGEROUS** | NEVER in production |

**Enforce this with ESLint:**

```jsonc
// .eslintrc.json
{
  "rules": {
    "no-restricted-properties": ["error", {
      "object": "prisma",
      "property": "$queryRawUnsafe",
      "message": "Use $queryRaw with tagged template literals instead"
    }, {
      "object": "prisma",
      "property": "$executeRawUnsafe",
      "message": "Use $executeRaw with tagged template literals instead"
    }]
  }
}
```

> ⚠️ **Common Mistake**: Thinking "Prisma handles it, so I don't need input validation." Prisma prevents *SQL injection* specifically, but it doesn't prevent: oversized strings blowing up your DB storage, invalid enum values causing runtime errors, or malicious content being stored and displayed later (stored XSS). Zod is your first line of defense.

---

## 5. 🚨 Abuse & Quota Drainage Prevention (防薅羊毛)

> **This is the most critical section.** LLM API calls cost real money. A single attacker with your API can drain hundreds of dollars in hours. StoryMe generates both text AND images (2048x2048) — image generation is especially expensive.

### Defense-in-Depth Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    REQUEST LIFECYCLE                          │
│                                                              │
│  Incoming Request                                            │
│       │                                                      │
│       ▼                                                      │
│  ┌──────────────────────────────────────────┐                │
│  │ LAYER 1: IP Rate Limiting (Redis)        │ ◄── Blocks    │
│  │ 60 req/min per IP                        │     DDoS,     │
│  │ No auth needed to enforce                │     scrapers  │
│  └──────────────┬───────────────────────────┘                │
│                 │ ✓ pass                                     │
│                 ▼                                            │
│  ┌──────────────────────────────────────────┐                │
│  │ LAYER 2: Auth Verification               │ ◄── Blocks   │
│  │ JWT + Device Attestation                 │     stolen    │
│  │                                          │     tokens,   │
│  └──────────────┬───────────────────────────┘     bots      │
│                 │ ✓ pass                                     │
│                 ▼                                            │
│  ┌──────────────────────────────────────────┐                │
│  │ LAYER 3: Per-User Rate Limiting          │ ◄── Blocks   │
│  │ 10 stories/hour, 30 stories/day          │     single-   │
│  │                                          │     account   │
│  └──────────────┬───────────────────────────┘     abuse     │
│                 │ ✓ pass                                     │
│                 ▼                                            │
│  ┌──────────────────────────────────────────┐                │
│  │ LAYER 4: Quota Check                     │ ◄── Blocks   │
│  │ Monthly token budget per user            │     quota     │
│  │ Check BEFORE calling LLM                 │     drain    │
│  └──────────────┬───────────────────────────┘                │
│                 │ ✓ pass                                     │
│                 ▼                                            │
│  ┌──────────────────────────────────────────┐                │
│  │ LAYER 5: Request Validation              │ ◄── Blocks   │
│  │ Max prompt length, max pages,            │     over-     │
│  │ cost estimation                          │     sized     │
│  └──────────────┬───────────────────────────┘     requests  │
│                 │ ✓ pass                                     │
│                 ▼                                            │
│  ┌──────────────────────────────────────────┐                │
│  │ FORWARD TO LLM API                       │                │
│  │ (Only reaches here after ALL checks)     │                │
│  └──────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

---

### Layer 1 — Network/IP Rate Limiting (Redis Token Bucket)

#### How the Token Bucket Algorithm Works

```
TOKEN BUCKET ALGORITHM
══════════════════════

Bucket capacity: 60 tokens
Refill rate: 1 token per second

Time 0:  Bucket = [████████████████████████████████████████] 60/60
         Request arrives → consume 1 token → ALLOW

Time 1:  Bucket = [███████████████████████████████████████ ] 59/60
         +1 refill → 60/60

         ... normal traffic ...

Time T:  BURST! 50 requests in 1 second
         Bucket = [████████████████████████████████████████] 60/60
         50 requests → consume 50 → ALLOW ALL
         Bucket = [██████████] 10/60

Time T+1: 20 more requests
          +1 refill → 11/60
          11 requests → ALLOW
          Bucket = [░] 0/60
          9 requests → REJECT (429 Too Many Requests)

Time T+2: 0 requests
          +1 refill → 1/60
          Bucket slowly recovers...

KEY INSIGHT: Allows short bursts (good UX) while enforcing
long-term averages (abuse prevention).
```

#### Redis Implementation

```typescript
// src/middleware/rateLimiter.ts
import { FastifyPluginAsync } from 'fastify';
import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL);

interface RateLimitConfig {
  key: string;         // e.g., "ip:192.168.1.1" or "user:uuid"
  maxTokens: number;   // Bucket capacity
  refillRate: number;   // Tokens added per second
  windowMs: number;     // TTL for the Redis key
}

async function checkRateLimit(config: RateLimitConfig): Promise<{
  allowed: boolean;
  remaining: number;
  retryAfterMs: number;
}> {
  const now = Date.now();
  const key = `ratelimit:${config.key}`;

  // Lua script for atomic token bucket (no race conditions)
  const luaScript = `
    local key = KEYS[1]
    local maxTokens = tonumber(ARGV[1])
    local refillRate = tonumber(ARGV[2])
    local now = tonumber(ARGV[3])
    local windowMs = tonumber(ARGV[4])

    local bucket = redis.call('HMGET', key, 'tokens', 'lastRefill')
    local tokens = tonumber(bucket[1])
    local lastRefill = tonumber(bucket[2])

    if tokens == nil then
      -- First request: initialize full bucket
      tokens = maxTokens - 1
      redis.call('HMSET', key, 'tokens', tokens, 'lastRefill', now)
      redis.call('PEXPIRE', key, windowMs)
      return {tokens, 0}
    end

    -- Calculate tokens to add since last refill
    local elapsed = (now - lastRefill) / 1000
    local newTokens = math.min(maxTokens, tokens + (elapsed * refillRate))

    if newTokens < 1 then
      -- No tokens available
      local waitTime = math.ceil((1 - newTokens) / refillRate * 1000)
      return {-1, waitTime}
    end

    -- Consume one token
    newTokens = newTokens - 1
    redis.call('HMSET', key, 'tokens', newTokens, 'lastRefill', now)
    redis.call('PEXPIRE', key, windowMs)
    return {newTokens, 0}
  `;

  const result = await redis.eval(
    luaScript, 1, key,
    config.maxTokens, config.refillRate, now, config.windowMs
  ) as [number, number];

  return {
    allowed: result[0] >= 0,
    remaining: Math.max(0, result[0]),
    retryAfterMs: result[1],
  };
}

// Fastify middleware
export const ipRateLimiter: FastifyPluginAsync = async (app) => {
  app.addHook('onRequest', async (req, reply) => {
    const ip = req.headers['x-forwarded-for'] as string || req.ip;

    const result = await checkRateLimit({
      key: `ip:${ip}`,
      maxTokens: 60,     // 60 requests
      refillRate: 1,      // 1 per second
      windowMs: 120_000,  // 2 minute window
    });

    reply.header('X-RateLimit-Remaining', result.remaining);

    if (!result.allowed) {
      reply.header('Retry-After', Math.ceil(result.retryAfterMs / 1000));
      return reply.code(429).send({
        error: 'Too many requests',
        retryAfterMs: result.retryAfterMs,
      });
    }
  });
};
```

#### Recommended Rate Limits

| Endpoint | IP Limit | User Limit | Why |
|----------|----------|------------|-----|
| `POST /auth/*` | 10/min | — | Prevent credential stuffing |
| `POST /api/stories/generate` | 5/min | 10/hour, 30/day | Most expensive (LLM + images) |
| `GET /api/stories/*` | 60/min | 120/min | Cheap reads, be generous |
| `POST /api/stories/*/pages` | 10/min | 20/hour | Image generation is costly |
| `POST /auth/refresh` | 5/min | 5/min | Prevent token farming |

---

### Layer 2 — Per-User Rate Limiting & Quota System

#### Quota Database Schema

```sql
┌──────────────────────────────────────────┐
│            usage_quotas                   │
├──────────────────────────────────────────┤
│ id              UUID  PK                 │
│ user_id         UUID  FK → users (UNIQUE)│
│ ──── Text API ────                       │
│ text_tokens_used      INT  DEFAULT 0     │
│ text_tokens_limit     INT  DEFAULT 500000│
│ ──── Image API ────                      │
│ images_generated      INT  DEFAULT 0     │
│ images_limit          INT  DEFAULT 100   │
│ ──── Stories ────                        │
│ stories_generated     INT  DEFAULT 0     │
│ stories_limit         INT  DEFAULT 50    │
│ ──── Billing ────                        │
│ period_start          TIMESTAMP          │
│ period_end            TIMESTAMP          │
│ reset_at              TIMESTAMP          │
│ ──── Meta ────                           │
│ tier          ENUM(free,premium)         │
│ created_at    TIMESTAMP                  │
│ updated_at    TIMESTAMP                  │
└──────────────────────────────────────────┘
```

#### Quota Check Middleware

```typescript
// src/middleware/quotaCheck.ts

interface QuotaCost {
  textTokens: number;  // Estimated tokens for this request
  images: number;       // Number of images to generate
  stories: number;      // 0 or 1
}

async function checkAndDeductQuota(
  userId: string,
  cost: QuotaCost
): Promise<{ allowed: boolean; reason?: string; remaining?: object }> {

  // Use a transaction to prevent race conditions
  return await prisma.$transaction(async (tx) => {
    const quota = await tx.usageQuota.findUnique({
      where: { userId },
    });

    if (!quota) {
      throw new Error('Quota record not found — data integrity issue');
    }

    // Check if period has expired → auto-reset
    if (new Date() > quota.resetAt) {
      await tx.usageQuota.update({
        where: { userId },
        data: {
          textTokensUsed: 0,
          imagesGenerated: 0,
          storiesGenerated: 0,
          periodStart: new Date(),
          periodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
          resetAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        },
      });
      // Re-fetch after reset
      return checkAndDeductQuota(userId, cost);
    }

    // Check each quota dimension
    if (quota.textTokensUsed + cost.textTokens > quota.textTokensLimit) {
      return { allowed: false, reason: 'Monthly text token quota exceeded' };
    }
    if (quota.imagesGenerated + cost.images > quota.imagesLimit) {
      return { allowed: false, reason: 'Monthly image generation quota exceeded' };
    }
    if (quota.storiesGenerated + cost.stories > quota.storiesLimit) {
      return { allowed: false, reason: 'Monthly story quota exceeded' };
    }

    // Deduct quota BEFORE making the LLM call (optimistic deduction)
    await tx.usageQuota.update({
      where: { userId },
      data: {
        textTokensUsed: { increment: cost.textTokens },
        imagesGenerated: { increment: cost.images },
        storiesGenerated: { increment: cost.stories },
      },
    });

    return {
      allowed: true,
      remaining: {
        textTokens: quota.textTokensLimit - quota.textTokensUsed - cost.textTokens,
        images: quota.imagesLimit - quota.imagesGenerated - cost.images,
        stories: quota.storiesLimit - quota.storiesGenerated - cost.stories,
      },
    };
  });
}
```

#### Quota Exceeded Response (Graceful Degradation)

```typescript
// When quota is hit, don't just return 403. Help the user understand.
if (!quotaResult.allowed) {
  return reply.code(429).send({
    error: 'quota_exceeded',
    message: quotaResult.reason,
    quota: {
      textTokens: { used: quota.textTokensUsed, limit: quota.textTokensLimit },
      images:     { used: quota.imagesGenerated, limit: quota.imagesLimit },
      stories:    { used: quota.storiesGenerated, limit: quota.storiesLimit },
    },
    resetsAt: quota.resetAt.toISOString(),
    upgradeUrl: 'storyme://upgrade', // Deep link to in-app upgrade
  });
}
```

#### Recommended Quota Tiers

| Resource | Free Tier | Premium Tier |
|----------|-----------|-------------|
| Stories/month | 10 | 100 |
| Text tokens/month | 100,000 | 2,000,000 |
| Images/month | 30 | 500 |
| Pages per story | 6 max | 12 max |
| Image resolution | 1024x1024 | 2048x2048 |

---

### Layer 3 — Apple App Attest & DeviceCheck (Critical)

#### Why App Attest Matters

Without device attestation, your backend has no way to know if a request comes from:
- ✅ A genuine StoryMe app on a real iPhone
- ❌ A Python script with a stolen JWT
- ❌ A modified/jailbroken app
- ❌ An Android emulator running your API calls

**App Attest** uses Apple's Secure Enclave to cryptographically prove the request comes from an unmodified copy of your app running on genuine Apple hardware.

#### App Attest Flow

```
ATTESTATION (one-time device registration)
══════════════════════════════════════════

┌──────────┐                    ┌──────────┐                 ┌──────────┐
│  iOS     │                    │  Your    │                 │  Apple   │
│  App     │                    │  Backend │                 │  Attest  │
│          │                    │          │                 │  Servers │
└────┬─────┘                    └────┬─────┘                 └────┬─────┘
     │                               │                            │
     │  1. Generate key pair         │                            │
     │  in Secure Enclave            │                            │
     │  (DCAppAttestService)         │                            │
     │                               │                            │
     │  2. GET /attest/challenge     │                            │
     │ ─────────────────────────────►│                            │
     │                               │                            │
     │  3. Return one-time nonce     │  (Store nonce in Redis     │
     │ ◄─────────────────────────────│   with 60s TTL)            │
     │                               │                            │
     │  4. Call Apple's attest()     │                            │
     │  with keyId + nonce hash      │                            │
     │ ──────────────────────────────────────────────────────────►│
     │                               │                            │
     │  5. Apple verifies:           │                            │
     │  - Real Apple hardware        │                            │
     │  - Unmodified app binary      │                            │
     │  - Valid App ID               │                            │
     │                               │                            │
     │  6. Returns attestation       │                            │
     │  object (CBOR-encoded)        │                            │
     │ ◄──────────────────────────────────────────────────────────│
     │                               │                            │
     │  7. POST /attest/verify       │                            │
     │  { keyId, attestation }       │                            │
     │ ─────────────────────────────►│                            │
     │                               │                            │
     │                               │  8. Verify attestation:    │
     │                               │  - Decode CBOR             │
     │                               │  - Check nonce matches     │
     │                               │  - Verify certificate      │
     │                               │    chain to Apple root     │
     │                               │  - Extract public key      │
     │                               │  - Store in DB:            │
     │                               │    device_attestations      │
     │                               │    (user_id, key_id,       │
     │                               │     public_key, counter)   │
     │                               │                            │
     │  9. { verified: true }        │                            │
     │ ◄─────────────────────────────│                            │
     ▼                               ▼                            ▼


ASSERTION (every subsequent API call)
═════════════════════════════════════

┌──────────┐                    ┌──────────┐
│  iOS     │                    │  Your    │
│  App     │                    │  Backend │
└────┬─────┘                    └────┬─────┘
     │                               │
     │  1. Before each API call:     │
     │  - Hash the request body      │
     │  - Call generateAssertion()   │
     │    with the hash              │
     │  - Secure Enclave signs       │
     │    with the attested key      │
     │                               │
     │  2. POST /api/stories/generate│
     │  Headers:                     │
     │    Authorization: Bearer JWT  │
     │    X-Apple-Assertion: <base64>│
     │    X-Apple-KeyId: <keyId>     │
     │  Body: { ... story params }   │
     │ ─────────────────────────────►│
     │                               │
     │                               │  3. Verify assertion:
     │                               │  - Look up device by keyId
     │                               │  - Verify signature with
     │                               │    stored public key
     │                               │  - Check counter >
     │                               │    stored counter
     │                               │    (replay prevention!)
     │                               │  - Increment stored counter
     │                               │  - Verify request hash
     │                               │    matches body
     │                               │
     │  4. Response                  │
     │ ◄─────────────────────────────│
     ▼                               ▼
```

#### Attestation vs Assertion — Key Distinction

| | Attestation | Assertion |
|--|-------------|-----------|
| **When** | Once, during device registration | Every API request |
| **Purpose** | Prove the device and app are genuine | Prove this specific request is genuine |
| **Involves Apple servers?** | Yes (certificate chain) | No (local signature verification) |
| **Cost** | Slow (~1-2s), involves network | Fast (~10ms), local crypto |
| **Analogy** | Getting a passport | Showing your passport at the border |

#### Backend Verification Endpoint

```typescript
// src/routes/attest.ts
import { verifyAttestation, verifyAssertion } from '../services/appAttest';

// Step 1: Issue a challenge nonce
app.get('/attest/challenge', async (req, reply) => {
  const nonce = crypto.randomBytes(32);
  const nonceHex = nonce.toString('hex');

  // Store in Redis with 60s TTL — prevents replay
  await redis.set(`attest:nonce:${nonceHex}`, req.user.id, 'EX', 60);

  return { nonce: nonceHex };
});

// Step 2: Verify attestation from device
app.post('/attest/verify', async (req, reply) => {
  const { keyId, attestation, nonce } = req.body;

  // Check nonce exists and belongs to this user
  const storedUserId = await redis.get(`attest:nonce:${nonce}`);
  if (!storedUserId || storedUserId !== req.user.id) {
    return reply.code(400).send({ error: 'Invalid or expired nonce' });
  }

  // Delete nonce immediately (one-time use)
  await redis.del(`attest:nonce:${nonce}`);

  try {
    const result = await verifyAttestation({
      attestation: Buffer.from(attestation, 'base64'),
      challenge: Buffer.from(nonce, 'hex'),
      keyId,
      bundleId: 'com.storyme.app',
      teamId: process.env.APPLE_TEAM_ID,
      allowDevelopment: process.env.NODE_ENV !== 'production',
    });

    // Store the verified device
    await prisma.deviceAttestation.create({
      data: {
        userId: req.user.id,
        keyId,
        publicKey: result.publicKey,   // For future assertion verification
        signCount: 0,                   // Counter for replay prevention
        environment: result.environment, // 'production' or 'development'
      },
    });

    return { verified: true };
  } catch (error) {
    // Log for security monitoring
    logger.warn({
      event: 'attestation_failed',
      userId: req.user.id,
      keyId,
      error: error.message,
    });
    return reply.code(403).send({ error: 'Device attestation failed' });
  }
});
```

#### Assertion Verification Middleware

```typescript
// src/middleware/assertionCheck.ts
export const requireAssertion: FastifyPluginAsync = async (app) => {
  app.addHook('preHandler', async (req, reply) => {
    const assertionB64 = req.headers['x-apple-assertion'] as string;
    const keyId = req.headers['x-apple-keyid'] as string;

    if (!assertionB64 || !keyId) {
      return reply.code(403).send({
        error: 'Device assertion required',
        code: 'MISSING_ATTESTATION',
      });
    }

    // Look up the attested device
    const device = await prisma.deviceAttestation.findUnique({
      where: {
        userId_keyId: { userId: req.user.id, keyId },
      },
    });

    if (!device) {
      return reply.code(403).send({
        error: 'Unregistered device. Please re-attest.',
        code: 'DEVICE_NOT_ATTESTED',
      });
    }

    // Verify the assertion
    const clientDataHash = crypto
      .createHash('sha256')
      .update(JSON.stringify(req.body) || '')
      .digest();

    const result = verifyAssertion({
      assertion: Buffer.from(assertionB64, 'base64'),
      clientDataHash,
      publicKey: device.publicKey,
      previousCounter: device.signCount,
      bundleId: 'com.storyme.app',
    });

    if (!result.valid) {
      logger.warn({
        event: 'assertion_failed',
        userId: req.user.id,
        keyId,
        reason: result.reason,
      });
      return reply.code(403).send({ error: 'Invalid device assertion' });
    }

    // Update counter (prevents replay attacks)
    await prisma.deviceAttestation.update({
      where: { userId_keyId: { userId: req.user.id, keyId } },
      data: { signCount: result.newCounter },
    });
  });
};
```

#### Replay Attack Prevention (Challenge-Nonce System)

```
WITHOUT NONCE (vulnerable to replay):
══════════════════════════════════════
Attacker captures: POST /api/stories/generate + assertion header
Attacker replays the EXACT same request → Backend accepts it! 💀

WITH NONCE + COUNTER (safe):
════════════════════════════
1. Each assertion includes a monotonic counter from Secure Enclave
2. Backend stores the last-seen counter per device
3. If incoming counter ≤ stored counter → REPLAY DETECTED → REJECT
4. Counter is hardware-enforced — cannot be faked or reset

Counter flow:
  Request 1: counter=1  → stored=0, 1>0 ✓ → update stored=1
  Request 2: counter=2  → stored=1, 2>1 ✓ → update stored=2
  Replay 1:  counter=1  → stored=2, 1>2 ✗ → REJECTED
  Replay 2:  counter=2  → stored=2, 2>2 ✗ → REJECTED
```

#### Honest Tradeoffs: What App Attest Does NOT Protect Against

| Limitation | Explanation |
|-----------|-------------|
| **Jailbroken devices (partially)** | Sophisticated jailbreaks can bypass some checks, but the Secure Enclave key is still hardware-bound |
| **Legitimate users abusing the app** | A real user on a real device can still spam requests — use quota limits |
| **MITM on the device itself** | If the device is compromised (e.g., malware), the attest still passes because the *device* is genuine |
| **Simulator/TestFlight** | Dev builds use a different attestation environment — handle this in your verification |
| **Older devices** | Devices before A12 chip (iPhone X and older) don't support App Attest — decide on a fallback (DeviceCheck or skip) |
| **First-request window** | Between app install and first attestation, you have no device proof — rate-limit heavily during this window |

---

### Layer 4 — LLM Request Guardrails

```typescript
// src/middleware/llmGuardrails.ts

const LLM_LIMITS = {
  // Per-request limits
  maxPromptChars: 2000,       // Your prompts are templated, so this is generous
  maxResponseTokens: 4000,    // Match current AIService.swift setting
  maxPagesPerStory: 12,
  maxImagesPerStory: 12,
  maxImageResolution: 2048,

  // Cost estimation (approximate, based on Volcengine pricing)
  costPerTextToken: 0.00002,  // ¥0.02 per 1K tokens
  costPerImage: 0.04,         // ¥0.04 per image
  maxCostPerRequest: 0.50,    // ¥0.50 kill switch
};

async function validateLLMRequest(req: FastifyRequest): Promise<{
  valid: boolean;
  estimatedCost: number;
  reason?: string;
}> {
  const { pageCount, style, childName, theme } = req.body as any;

  // 1. Prompt length check
  const promptLength = [childName, theme, style].join(' ').length;
  if (promptLength > LLM_LIMITS.maxPromptChars) {
    return { valid: false, estimatedCost: 0, reason: 'Prompt too long' };
  }

  // 2. Page count check
  if (pageCount > LLM_LIMITS.maxPagesPerStory) {
    return {
      valid: false,
      estimatedCost: 0,
      reason: `Maximum ${LLM_LIMITS.maxPagesPerStory} pages per story`,
    };
  }

  // 3. Cost estimation
  const estimatedTextTokens = pageCount * 300; // ~300 tokens per page
  const estimatedImages = pageCount;            // 1 image per page
  const estimatedCost =
    (estimatedTextTokens * LLM_LIMITS.costPerTextToken) +
    (estimatedImages * LLM_LIMITS.costPerImage);

  // 4. Kill switch: reject if estimated cost exceeds threshold
  if (estimatedCost > LLM_LIMITS.maxCostPerRequest) {
    return {
      valid: false,
      estimatedCost,
      reason: `Estimated cost ¥${estimatedCost.toFixed(2)} exceeds limit`,
    };
  }

  return { valid: true, estimatedCost };
}

// Streaming abuse prevention
// Your current AIService uses non-streaming responses, but if you add streaming:
const STREAM_LIMITS = {
  maxStreamDurationMs: 120_000,  // 2 minutes max (match current timeout)
  heartbeatIntervalMs: 15_000,   // Send keepalive every 15s
  maxIdleMs: 30_000,             // Kill if no data for 30s
};
```

> ⚠️ **Common Mistake**: Only rate-limiting by request count and ignoring token cost. An attacker can send 1 request with `maxTokens: 100000` and drain more quota than 100 normal requests. Always limit **both** request count AND token/cost budget.

---

## 6. 🗃️ Database Schema Design

### Full Prisma Schema

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// ============================================================
// USER & AUTHENTICATION
// ============================================================

model User {
  id        String   @id @default(uuid()) @db.Uuid
  appleId   String   @unique @map("apple_id")  // Apple's user identifier (sub claim)
  email     String?  // Apple relay email (may be null if user hides it)
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  // Relations
  sessions           Session[]
  stories             Story[]
  usageQuota          UsageQuota?
  deviceAttestations  DeviceAttestation[]

  // Security: prevent deleted users from leaving orphan data
  @@index([appleId])
  @@map("users")
}

model Session {
  id           String   @id @default(uuid()) @db.Uuid
  userId       String   @map("user_id") @db.Uuid
  refreshToken String   @unique @map("refresh_token")  // Hashed, not plaintext!
  jti          String   @unique                         // JWT ID for revocation
  expiresAt    DateTime @map("expires_at")
  createdAt    DateTime @default(now()) @map("created_at")
  revokedAt    DateTime? @map("revoked_at")             // Soft revocation
  deviceInfo   String?  @map("device_info")             // "iPhone 15, iOS 17.4"
  ipAddress    String?  @map("ip_address")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([expiresAt])
  @@map("sessions")
}

// ============================================================
// STORIES & CONTENT
// ============================================================

model Story {
  id             String     @id @default(uuid()) @db.Uuid
  userId         String     @map("user_id") @db.Uuid
  title          String
  childName      String     @map("child_name")
  theme          StoryTheme
  style          StoryStyle
  isFavorite     Boolean    @default(false) @map("is_favorite")
  lastReadPage   Int        @default(0) @map("last_read_page")
  createdAt      DateTime   @default(now()) @map("created_at")
  updatedAt      DateTime   @updatedAt @map("updated_at")
  lastReadAt     DateTime?  @map("last_read_at")

  // Cost tracking (for monitoring)
  textTokensUsed Int       @default(0) @map("text_tokens_used")
  imageCount     Int       @default(0) @map("image_count")

  // Relations
  user  User        @relation(fields: [userId], references: [id], onDelete: Cascade)
  pages StoryPage[]

  // CRITICAL: This compound index powers ownership-scoped queries
  @@index([userId, createdAt(sort: Desc)])
  @@index([userId, isFavorite])
  @@map("stories")
}

model StoryPage {
  id               String  @id @default(uuid()) @db.Uuid
  storyId          String  @map("story_id") @db.Uuid
  pageNumber       Int     @map("page_number")
  text             String  @db.Text
  imageDescription String  @map("image_description") @db.Text
  emoji            String  @default("")

  // Image stored in object storage (S3/R2), NOT in DB
  imageUrl         String? @map("image_url")
  imageStorageKey  String? @map("image_storage_key") // S3 key for deletion

  story Story @relation(fields: [storyId], references: [id], onDelete: Cascade)

  @@unique([storyId, pageNumber])
  @@map("story_pages")
}

enum StoryTheme {
  adventure
  fantasy
  animals
  space
  ocean
  dinosaurs
}

enum StoryStyle {
  warmCozy
  adventure
  fantasy
}

// ============================================================
// USAGE & QUOTAS
// ============================================================

model UsageQuota {
  id              String   @id @default(uuid()) @db.Uuid
  userId          String   @unique @map("user_id") @db.Uuid
  tier            UserTier @default(free)

  // Text API usage
  textTokensUsed  Int      @default(0) @map("text_tokens_used")
  textTokensLimit Int      @default(100000) @map("text_tokens_limit")

  // Image API usage
  imagesGenerated Int      @default(0) @map("images_generated")
  imagesLimit     Int      @default(30) @map("images_limit")

  // Story count
  storiesGenerated Int     @default(0) @map("stories_generated")
  storiesLimit     Int     @default(10) @map("stories_limit")

  // Billing period
  periodStart     DateTime @default(now()) @map("period_start")
  periodEnd       DateTime @map("period_end")
  resetAt         DateTime @map("reset_at")

  createdAt       DateTime @default(now()) @map("created_at")
  updatedAt       DateTime @updatedAt @map("updated_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("usage_quotas")
}

enum UserTier {
  free
  premium
}

// ============================================================
// DEVICE ATTESTATION (App Attest)
// ============================================================

model DeviceAttestation {
  id          String   @id @default(uuid()) @db.Uuid
  userId      String   @map("user_id") @db.Uuid
  keyId       String   @map("key_id")         // Apple-assigned key identifier
  publicKey   Bytes    @map("public_key")      // For assertion verification
  signCount   Int      @default(0) @map("sign_count") // Monotonic counter
  environment String   @default("production")  // 'production' or 'development'
  createdAt   DateTime @default(now()) @map("created_at")
  lastUsedAt  DateTime @default(now()) @map("last_used_at")
  revokedAt   DateTime? @map("revoked_at")

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, keyId])
  @@index([keyId])
  @@map("device_attestations")
}
```

### Field Security Purposes

| Table | Field | Security Purpose |
|-------|-------|-----------------|
| `users.apple_id` | Unique identity anchor — even if email changes, Apple ID is permanent |
| `sessions.refresh_token` | **Stored as SHA-256 hash**, not plaintext — DB leak doesn't compromise sessions |
| `sessions.jti` | Unique token ID enables instant revocation via Redis blocklist |
| `sessions.revoked_at` | Soft-delete for audit trail — know when and why sessions were killed |
| `stories.user_id` + index | Compound index ensures ownership queries are O(1) |
| `usage_quotas.reset_at` | Automatic period reset — prevents manual reset manipulation |
| `device_attestations.sign_count` | Monotonic counter — replay attacks cause counter mismatch |
| `device_attestations.revoked_at` | Remote wipe: revoke a stolen device without deleting audit trail |

### Index Strategy

```
PERFORMANCE + SECURITY INDEXES
══════════════════════════════

users:
  └── UNIQUE(apple_id)           → O(1) login lookup

sessions:
  ├── UNIQUE(refresh_token)      → O(1) token lookup (hashed)
  ├── UNIQUE(jti)                → O(1) revocation check
  ├── INDEX(user_id)             → "show all my sessions"
  └── INDEX(expires_at)          → Cleanup job: delete expired sessions

stories:
  ├── INDEX(user_id, created_at DESC) → "my stories, newest first" (main query)
  └── INDEX(user_id, is_favorite)     → "my favorite stories" filter

story_pages:
  └── UNIQUE(story_id, page_number)   → Prevent duplicate pages

device_attestations:
  ├── UNIQUE(user_id, key_id)    → One attestation per device per user
  └── INDEX(key_id)              → Fast assertion lookup by key ID
```

> ⚠️ **Common Mistake**: Storing images as binary data in PostgreSQL (your current `StoryPage.imageData: Data?` in Swift). This bloats the DB, slows backups, and makes it impossible to use a CDN. Store images in S3/R2/Cloudflare Images and save only the URL/key in the DB.

---

## 7. 🚀 Deployment & Secrets Management

### Secrets Storage — Never in Code

Your current `Secrets.xcconfig` is committed to Git with plaintext API keys. This must be eliminated.

```
SECRETS MANAGEMENT HIERARCHY
═════════════════════════════

┌─────────────────────────────────────────────────────┐
│                                                      │
│  ❌ NEVER                                            │
│  ├── Hardcoded in source code                        │
│  ├── In .xcconfig committed to git                   │
│  ├── In docker-compose.yml                           │
│  └── In CI/CD pipeline YAML                          │
│                                                      │
│  ⚠️ ACCEPTABLE (development only)                    │
│  ├── .env file (MUST be in .gitignore)               │
│  └── Local Keychain / macOS Keychain Access          │
│                                                      │
│  ✅ PRODUCTION                                       │
│  ├── AWS Secrets Manager                             │
│  ├── Doppler (easiest, great DX)                     │
│  ├── Infisical (open-source option)                  │
│  ├── HashiCorp Vault (enterprise)                    │
│  └── Railway/Fly.io native secrets                   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Recommended: Doppler for Simplicity

```bash
# Install & setup
brew install dopplerhq/cli/doppler
doppler login
doppler setup  # Select project + environment

# Your app reads secrets at runtime:
doppler run -- node dist/server.js

# Secrets are injected as env vars — zero code changes needed
# process.env.DOUBAO_TEXT_API_KEY "just works"
```

### Environment Variables Needed

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/storyme?sslmode=require

# Redis
REDIS_URL=redis://:password@host:6379/0

# LLM APIs (moved from Secrets.xcconfig to backend-only)
DOUBAO_TEXT_API_KEY=****
DOUBAO_TEXT_MODEL_ID=ep-xxxx
DOUBAO_IMAGE_API_KEY=****
DOUBAO_IMAGE_MODEL_ID=ep-xxxx

# Auth
JWT_PRIVATE_KEY=<RS256 PEM private key>
JWT_PUBLIC_KEY=<RS256 PEM public key>
APPLE_TEAM_ID=XXXXXXXXXX

# App
NODE_ENV=production
PORT=3000
CORS_ORIGIN=https://storyme.app  # Not strictly needed for mobile, but good practice
```

### HTTPS & Mobile Security

```typescript
// src/server.ts — security configuration

import fastifyHelmet from '@fastify/helmet';
import fastifyCors from '@fastify/cors';

// Helmet — HTTP security headers
app.register(fastifyHelmet, {
  // Strict transport security (HTTPS only)
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  // Prevent MIME sniffing
  noSniff: true,
  // No need for CSP/XSS filter — this is a JSON API, not HTML
  contentSecurityPolicy: false,
});

// CORS — for mobile, this is mostly about blocking browser abuse
app.register(fastifyCors, {
  origin: false,  // No browser origins allowed (mobile-only API)
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
});

// Request size limits — prevent large payload attacks
app.register(import('@fastify/multipart'), {
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max for photo uploads
});

// Force HTTPS in production
if (process.env.NODE_ENV === 'production') {
  app.addHook('onRequest', async (req, reply) => {
    if (req.headers['x-forwarded-proto'] !== 'https') {
      return reply.code(301).redirect(`https://${req.hostname}${req.url}`);
    }
  });
}
```

### Hosting Comparison

| Platform | Pros | Cons | Cost (low traffic) |
|----------|------|------|--------------------|
| **Railway** | Easiest setup, built-in Postgres + Redis, auto-deploy from Git | Limited regions (US/EU only) | ~$5–10/mo |
| **Fly.io** | Multi-region, great latency for global users, Docker-based | Steeper learning curve | ~$5–15/mo |
| **AWS ECS** | Full control, enterprise-grade | Complex setup, overkill for early stage | ~$20–50/mo |
| **Render** | Simple, managed Postgres | Slower deploys, cold starts on free tier | ~$7–15/mo |

**Recommendation**: Start with **Railway** for fastest time-to-production. It supports Postgres, Redis, and auto-deploy from your GitHub repo. Migrate to Fly.io or AWS when you need multi-region (China users may need a separate deployment with Alibaba Cloud).

> ⚠️ **Common Mistake**: Running the database and app on the same server. Always use managed PostgreSQL (Railway Postgres, RDS, Supabase) — it handles backups, failover, and security patches. Your server should be stateless and disposable.

---

## 8. 📊 Monitoring & Incident Response

### What to Monitor

```
MONITORING DASHBOARD
════════════════════

┌────────────────────────────────────────────────┐
│          REAL-TIME METRICS                      │
│                                                 │
│  🟢 API Requests/min    ████████░░  142/200     │
│  🟢 Avg Response Time   ██░░░░░░░░  340ms       │
│  🟢 Error Rate          ░░░░░░░░░░  0.3%        │
│  🟡 LLM Token Usage     ██████░░░░  62% quota   │
│  🟢 Active Users        ███░░░░░░░  47          │
│                                                 │
│  ⚠️  ALERT THRESHOLDS                           │
│  ├── Error rate > 5%           → Page oncall    │
│  ├── Token usage > 80%/day    → Slack warning   │
│  ├── Single user > 20 req/hr  → Auto-throttle  │
│  ├── Auth failures > 50/hr    → Investigate     │
│  ├── Attestation fails > 10%  → Bot attack?     │
│  └── LLM cost > ¥100/day     → Kill switch     │
│                                                 │
└────────────────────────────────────────────────┘
```

### Key Metrics to Track

```typescript
// src/services/metrics.ts
// Use Prometheus client or a managed service like Datadog/Grafana Cloud

const metrics = {
  // Request-level
  httpRequestDuration: new Histogram({ name: 'http_request_duration_seconds' }),
  httpRequestTotal: new Counter({ name: 'http_request_total', labels: ['method', 'route', 'status'] }),

  // Auth
  authAttempts: new Counter({ name: 'auth_attempts_total', labels: ['result'] }), // success/failure
  tokenRefreshes: new Counter({ name: 'token_refreshes_total' }),
  attestationResults: new Counter({ name: 'attestation_results_total', labels: ['result'] }),

  // LLM / Cost
  llmTokensUsed: new Counter({ name: 'llm_tokens_used_total', labels: ['api', 'model'] }),
  llmRequestDuration: new Histogram({ name: 'llm_request_duration_seconds', labels: ['api'] }),
  llmCostEstimate: new Counter({ name: 'llm_cost_estimate_total', labels: ['api'] }),
  llmErrors: new Counter({ name: 'llm_errors_total', labels: ['api', 'error_type'] }),

  // Abuse detection
  rateLimitHits: new Counter({ name: 'rate_limit_hits_total', labels: ['type'] }), // ip/user
  quotaExceeded: new Counter({ name: 'quota_exceeded_total', labels: ['resource'] }),

  // Business
  storiesGenerated: new Counter({ name: 'stories_generated_total' }),
  activeUsers: new Gauge({ name: 'active_users' }),
};
```

### Alerting Strategy

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Error rate | > 2% for 5min | > 5% for 2min | Check logs, rollback if deploy-related |
| LLM daily cost | > 80% budget | > 100% budget | Warning → Kill switch (reject new requests) |
| Auth failures from single IP | > 20/hour | > 50/hour | Add IP to temporary blocklist |
| Attestation failure rate | > 5% | > 15% | Investigate — possible bot network |
| Single user token usage | > 3x average | > 10x average | Auto-throttle → flag for review |
| Database connection pool | > 80% utilized | > 95% | Scale up, check for connection leaks |
| Response time P99 | > 5s | > 15s | Check LLM API status, circuit break |

### Emergency: Kill a Compromised User Account

```typescript
// src/services/accountKill.ts

async function killUserAccount(userId: string, reason: string): Promise<void> {
  // 1. Revoke all sessions immediately
  await prisma.session.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });

  // 2. Add all user's JTIs to Redis blocklist
  const sessions = await prisma.session.findMany({
    where: { userId },
    select: { jti: true },
  });
  const pipeline = redis.pipeline();
  for (const session of sessions) {
    pipeline.set(`blocklist:jti:${session.jti}`, '1', 'EX', 86400); // 24h TTL
  }
  await pipeline.exec();

  // 3. Revoke all device attestations
  await prisma.deviceAttestation.updateMany({
    where: { userId },
    data: { revokedAt: new Date() },
  });

  // 4. Set quota to zero (prevent any new requests even if token leaks through)
  await prisma.usageQuota.update({
    where: { userId },
    data: {
      textTokensLimit: 0,
      imagesLimit: 0,
      storiesLimit: 0,
    },
  });

  // 5. Log the kill for audit
  logger.warn({
    event: 'account_killed',
    userId,
    reason,
    timestamp: new Date().toISOString(),
  });
}

// Usage:
// await killUserAccount('user-uuid', 'Detected automated abuse pattern');
```

> ⚠️ **Common Mistake**: Only logging errors and ignoring success patterns. You need to baseline normal behavior (average stories/user/day, typical token usage per story) so that anomalies stand out. An attacker who stays just under rate limits is invisible without behavioral baselines.

---

## 9. ✅ Security Checklist

> Run through this checklist before every release. Every item must be verified.

### Authentication & Authorization

- [ ] API keys live ONLY in the backend, never in the iOS app bundle
- [ ] `Secrets.xcconfig` is removed from git history (use `git filter-branch` or BFG)
- [ ] Sign in with Apple identity token is verified against Apple's JWKS endpoint
- [ ] JWTs are signed with RS256, not HS256
- [ ] Access tokens expire in ≤ 15 minutes
- [ ] Refresh tokens are rotated on every use
- [ ] Refresh tokens are stored as SHA-256 hashes in the database
- [ ] iOS app stores tokens in Keychain, never in UserDefaults
- [ ] Token revocation blocklist is checked on every request (via Redis)

### BOLA / Access Control

- [ ] Every database query includes `userId` from the JWT (never from request params)
- [ ] Resource-not-found returns 404, never 403
- [ ] No endpoint accepts `userId` as an input parameter
- [ ] PostgreSQL RLS policies are enabled on all user-scoped tables
- [ ] UUIDs are used for all resource identifiers (no sequential IDs)

### Input Validation

- [ ] Every endpoint has a Zod schema that validates all inputs
- [ ] Prisma ORM is used for all queries (no raw SQL in production code)
- [ ] `$queryRawUnsafe` and `$executeRawUnsafe` are banned via ESLint
- [ ] Request body size is limited (e.g., 1MB for JSON, 5MB for images)
- [ ] Child names and prompts are sanitized against injection

### Abuse Prevention

- [ ] IP-level rate limiting is enforced via Redis (60 req/min default)
- [ ] Per-user rate limiting is enforced (10 stories/hour)
- [ ] Monthly quota system is active with per-user tracking
- [ ] Quota is deducted BEFORE the LLM call, not after
- [ ] Apple App Attest is required for all authenticated endpoints
- [ ] Attestation nonces are single-use with 60s TTL
- [ ] Assertion counter is checked and incremented atomically
- [ ] Max prompt length and max tokens per request are enforced
- [ ] Cost estimation rejects requests exceeding the per-request threshold
- [ ] A daily cost kill switch exists and is tested

### Data Security

- [ ] HTTPS is enforced (no plaintext HTTP in production)
- [ ] Database connections use SSL (`sslmode=require`)
- [ ] Child appearance data is handled as PII (minimize retention)
- [ ] Images are stored in object storage (S3/R2), not in the database
- [ ] Database backups are encrypted at rest
- [ ] COPPA compliance: no unnecessary data collection from children

### Deployment

- [ ] All secrets are in a secret manager (Doppler/AWS Secrets Manager)
- [ ] No secrets in Docker images, git history, or CI/CD logs
- [ ] Database is managed (not self-hosted) with automatic backups
- [ ] Server is stateless — can be destroyed and recreated
- [ ] Health check endpoint exists (`GET /health`)
- [ ] Graceful shutdown handles in-flight requests

### Monitoring

- [ ] Structured logging (JSON) with request IDs for tracing
- [ ] LLM cost tracking with daily alerts
- [ ] Auth failure spike detection
- [ ] Anomalous usage detection (behavioral baselines)
- [ ] Account kill procedure is documented and tested
- [ ] Incident response runbook exists

---

## 📚 Appendix: Recommended Project Structure

```
backend/
├── prisma/
│   ├── schema.prisma           # Database schema (above)
│   └── migrations/             # Auto-generated by Prisma
├── src/
│   ├── server.ts               # Fastify app setup + plugin registration
│   ├── config.ts               # Environment variable validation (with Zod)
│   ├── plugins/
│   │   ├── auth.ts             # JWT verification plugin
│   │   ├── ownership.ts        # BOLA prevention (auto-scoping)
│   │   └── errorHandler.ts     # Consistent error responses
│   ├── middleware/
│   │   ├── rateLimiter.ts      # Redis token bucket (IP + user)
│   │   ├── quotaCheck.ts       # Usage quota enforcement
│   │   ├── assertionCheck.ts   # App Attest verification
│   │   └── llmGuardrails.ts    # Cost estimation + limits
│   ├── routes/
│   │   ├── auth.ts             # POST /auth/apple, /auth/refresh
│   │   ├── attest.ts           # GET /attest/challenge, POST /attest/verify
│   │   ├── stories.ts          # CRUD + generate
│   │   └── health.ts           # GET /health
│   ├── services/
│   │   ├── llmProxy.ts         # Volcengine/Doubao API client
│   │   ├── appleAuth.ts        # Apple identity token verification
│   │   ├── appAttest.ts        # Attestation + assertion verification
│   │   ├── imageStorage.ts     # S3/R2 upload + signed URLs
│   │   └── accountKill.ts      # Emergency account kill
│   ├── schemas/                # Zod validation schemas
│   │   ├── auth.ts
│   │   ├── stories.ts
│   │   └── attest.ts
│   └── utils/
│       ├── jwt.ts              # Sign + verify helpers
│       └── logger.ts           # Pino logger configuration
├── tests/
│   ├── integration/            # Tests against real DB (Docker Compose)
│   └── unit/                   # Pure function tests
├── docker-compose.yml          # Local dev: Postgres + Redis
├── Dockerfile                  # Production container
├── package.json
├── tsconfig.json
└── .env.example                # Template (no real secrets)
```

---

*This document is a living reference. Update it as your architecture evolves. Last generated: April 2026.*
