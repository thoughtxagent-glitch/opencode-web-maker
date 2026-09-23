# Architecture Patterns Mastery — Bxploit Knowledge Base
> Project Architecture, Tech Stack Decision & Full Structure Guide
> Last updated: 2026-09-18 | Language: ID + EN Tech Terms

---

## TL;DR

Lo mau bikin website tapi bingung stack apa yang dipake? File ini adalah **source of truth** lo. Dari SaaS sampe E-commerce, dari landing page sampe real-time chat — semua ada di sini. Gue kasih decision tree, folder structure, code snippets nyata, dan pitfall yang biasa orang salah.

---

## 1. TECH STACK DECISION FRAMEWORK

Sebelum pilih stack, jawab 3 pertanyaan ini:

```
1. Siapa user lo? (B2B / B2C / internal tool)
2. Traffic expectation? (100/day vs 100k/day)
3. Tim lo seberapa gede? (solo / 2-5 / 10+)
```

Jawaban itu nentuin segalanya. Jangan over-engineer buat project yang usernya 50 orang.

---

### 1.1 Project Type 1: SaaS Full-Stack App

**Kapan**: Produk berbayar, user management, subscription, fitur kompleks.

**Stack Optimal**:

| Layer | Pilihan | Alasan |
|---|---|---|
| Frontend | Next.js 14+ App Router + TypeScript | SSR + RSC = performa optimal |
| Styling | Tailwind CSS + shadcn/ui | DX cepat, customizable |
| Backend | Next.js Route Handlers / Server Actions | Monolith sederhana, satu deployment |
| Auth | Auth.js v5 (NextAuth) | Support 50+ providers, JWT/session |
| DB | PostgreSQL via Neon/Supabase | Relational, ACID compliant |
| ORM | Drizzle ORM | Type-safe, lightweight, SQL-like syntax |
| State | Zustand + TanStack Query | Client state + server state separation |
| Email | Resend + React Email | Developer-first email API |
| Payments | Stripe | Industry standard, semua fitur ada |
| Deployment | Vercel + Neon/Supabase | Zero-config, scale otomatis |

**Decision Tree SaaS**:
```
Butuh real-time?
├── YES → Tambah Socket.io atau Supabase Realtime
└── NO  → Pure HTTP cukup

Traffic > 10k req/hari?
├── YES → Pisahkan API ke separate service (Type 2)
└── NO  → Next.js monolith cukup

Multi-tenant?
├── YES → Row-level security di Supabase / schema per tenant
└── NO  → Single tenant biasa
```

**Folder Structure SaaS Next.js**:
```
my-saas/
├── src/
│   ├── app/                          # Next.js App Router
│   │   ├── (auth)/                   # Route group: unauthenticated
│   │   │   ├── login/
│   │   │   │   └── page.tsx
│   │   │   ├── register/
│   │   │   │   └── page.tsx
│   │   │   └── forgot-password/
│   │   │       └── page.tsx
│   │   ├── (dashboard)/              # Route group: protected
│   │   │   ├── layout.tsx            # Dashboard shell (sidebar, topbar)
│   │   │   ├── dashboard/
│   │   │   │   └── page.tsx
│   │   │   ├── settings/
│   │   │   │   ├── profile/page.tsx
│   │   │   │   ├── billing/page.tsx
│   │   │   │   └── team/page.tsx
│   │   │   └── [feature]/
│   │   │       └── page.tsx
│   │   ├── api/                      # Route Handlers
│   │   │   ├── auth/[...nextauth]/
│   │   │   │   └── route.ts
│   │   │   ├── webhooks/
│   │   │   │   └── stripe/route.ts
│   │   │   └── v1/
│   │   │       └── [resource]/route.ts
│   │   ├── layout.tsx
│   │   └── globals.css
│   │
│   ├── components/
│   │   ├── ui/                       # shadcn/ui base components
│   │   │   ├── button.tsx
│   │   │   ├── input.tsx
│   │   │   ├── dialog.tsx
│   │   │   └── ...
│   │   ├── forms/                    # Form-specific components
│   │   │   ├── login-form.tsx
│   │   │   └── subscription-form.tsx
│   │   ├── features/                 # Feature-scoped components
│   │   │   ├── billing/
│   │   │   │   ├── pricing-table.tsx
│   │   │   │   └── invoice-list.tsx
│   │   │   └── dashboard/
│   │   │       ├── stats-card.tsx
│   │   │       └── activity-feed.tsx
│   │   └── layout/
│   │       ├── sidebar.tsx
│   │       └── topbar.tsx
│   │
│   ├── lib/                          # Core utilities (isomorphic)
│   │   ├── db/
│   │   │   ├── client.ts             # Drizzle client singleton
│   │   │   ├── schema.ts             # Table definitions
│   │   │   └── migrations/
│   │   ├── auth/
│   │   │   ├── config.ts             # Auth.js config
│   │   │   └── permissions.ts        # RBAC helpers
│   │   ├── validators/               # Zod schemas (shared FE+BE)
│   │   │   ├── auth.ts
│   │   │   ├── user.ts
│   │   │   └── billing.ts
│   │   ├── stripe/
│   │   │   ├── client.ts
│   │   │   └── webhooks.ts
│   │   └── utils.ts
│   │
│   ├── server/                       # Server-only code (never bundled to client)
│   │   ├── actions/                  # Next.js Server Actions
│   │   │   ├── auth.actions.ts
│   │   │   ├── user.actions.ts
│   │   │   └── billing.actions.ts
│   │   ├── services/                 # Business logic layer
│   │   │   ├── auth.service.ts
│   │   │   ├── user.service.ts
│   │   │   └── billing.service.ts
│   │   └── repositories/            # Data access layer
│   │       ├── user.repository.ts
│   │       └── subscription.repository.ts
│   │
│   ├── hooks/                        # Custom React hooks
│   │   ├── use-user.ts
│   │   └── use-subscription.ts
│   ├── store/                        # Zustand stores
│   │   ├── ui.store.ts               # UI state (sidebar open, theme)
│   │   └── auth.store.ts
│   └── types/
│       ├── index.ts
│       └── database.ts               # Inferred Drizzle types
│
├── drizzle/
│   └── migrations/                   # Generated migration files
├── public/
├── .env.local
├── .env.example
├── drizzle.config.ts
├── next.config.ts
├── tailwind.config.ts
└── package.json
```

---

### 1.2 Project Type 2: High-Traffic API Backend

**Kapan**: Butuh throughput tinggi, pure API (no SSR), microservice-ready.

**Stack Optimal**:

| Layer | Pilihan | Alasan |
|---|---|---|
| Runtime | Node.js 22+ LTS | Stability + performance |
| Framework | Fastify | 2x lebih cepat dari Express, built-in schema validation |
| Language | TypeScript | Type safety |
| Validation | Zod | Runtime validation + type inference |
| DB | PostgreSQL | Relational ACID |
| ORM | Drizzle / Prisma | Drizzle lebih lightweight, Prisma lebih ergonomic |
| Cache | Redis (ioredis) | Session, rate limiting, caching |
| Queue | BullMQ | Job processing, retries, cron |
| Auth | JWT RS256 | Stateless, scalable |
| Monitoring | OpenTelemetry + Grafana | Observability |
| Deployment | Docker + Railway / Fly.io / AWS ECS | Container-first |

**Folder Structure Fastify API**:
```
api/
├── src/
│   ├── plugins/                  # Fastify plugins
│   │   ├── auth.ts               # JWT verification plugin
│   │   ├── cors.ts
│   │   ├── rate-limit.ts
│   │   └── swagger.ts
│   ├── routes/                   # Route handlers (thin layer)
│   │   ├── v1/
│   │   │   ├── users/
│   │   │   │   ├── index.ts      # GET /users, POST /users
│   │   │   │   └── [id].ts       # GET /users/:id, PATCH, DELETE
│   │   │   └── index.ts          # Route registration
│   │   └── health.ts
│   ├── services/                 # Business logic
│   │   ├── user.service.ts
│   │   └── notification.service.ts
│   ├── repositories/             # DB queries
│   │   ├── user.repository.ts
│   │   └── base.repository.ts
│   ├── middleware/
│   │   ├── authenticate.ts
│   │   └── validate.ts
│   ├── jobs/                     # BullMQ workers
│   │   ├── email.job.ts
│   │   └── cleanup.job.ts
│   ├── lib/
│   │   ├── db.ts                 # Database client
│   │   ├── redis.ts              # Redis client
│   │   ├── logger.ts             # Pino logger
│   │   └── env.ts                # Validated env vars
│   ├── schemas/                  # Zod schemas + JSON Schema
│   │   ├── user.schema.ts
│   │   └── common.schema.ts
│   ├── types/
│   └── app.ts                    # Fastify app setup
├── Dockerfile
├── docker-compose.yml
└── package.json
```

**Sample Fastify Route Pattern**:
```typescript
// routes/v1/users/index.ts
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod'
import { z } from 'zod'
import { UserService } from '@/services/user.service'

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
  role: z.enum(['user', 'admin']).default('user'),
})

const plugin: FastifyPluginAsyncZod = async (app) => {
  app.post('/', {
    schema: {
      body: CreateUserSchema,
      response: {
        201: z.object({ id: z.string(), email: z.string() }),
        400: z.object({ message: z.string() }),
      },
    },
    preHandler: [app.authenticate],
  }, async (request, reply) => {
    const user = await UserService.create(request.body)
    return reply.status(201).send(user)
  })
}

export default plugin
```

---

### 1.3 Project Type 3: E-Commerce

**Kapan**: Toko online, product catalog, cart, checkout, order management.

**Stack Optimal**:

| Layer | Pilihan | Alasan |
|---|---|---|
| Frontend | Next.js (SSR/ISR) | SEO critical untuk product pages |
| DB Primary | PostgreSQL | Products, orders, users |
| DB Cache | Redis | Cart, session, flash sales |
| Search | Meilisearch (self-hosted) / Algolia | Full-text search |
| Storage | Cloudflare R2 / AWS S3 | Product images |
| CDN | Cloudflare | Image optimization, edge cache |
| Payments | Stripe Checkout / Elements | Semua yang lo butuh ada |
| Email | Resend | Order confirmation, shipping updates |
| Analytics | PostHog | Funnel tracking, heatmaps |

**Critical Consideration E-Commerce**:
- Product pages: ISR dengan `revalidate: 60` — fresh tapi cepat
- Cart: jangan di DB terus-terusan, pake Redis + sync ke DB waktu checkout
- Inventory: optimistic locking untuk mencegah overselling
- Search: PostgreSQL full-text search cukup untuk < 100k products

```typescript
// Contoh ISR untuk product page
// app/products/[slug]/page.tsx
export const revalidate = 60 // Revalidate tiap 60 detik

export async function generateStaticParams() {
  const products = await db.query.products.findMany({
    columns: { slug: true },
    where: eq(products.status, 'active'),
  })
  return products.map((p) => ({ slug: p.slug }))
}

export async function generateMetadata({ params }: Props) {
  const product = await getProductBySlug(params.slug)
  return {
    title: product.name,
    description: product.description,
    openGraph: {
      images: [product.imageUrl],
    },
  }
}
```

---

### 1.4 Project Type 4: Real-Time App (Chat / Collaboration)

**Kapan**: Chat, live collaboration, presence indicators, live notifications.

**Stack Optimal**:

| Layer | Pilihan | Alasan |
|---|---|---|
| Frontend | Next.js + Socket.io client | SSR for initial load |
| WS Server | Node.js + Socket.io | Mature, room support |
| Adapter | Socket.io Redis Adapter | Multi-node support |
| DB | PostgreSQL | Message history |
| Cache | Redis | Presence, typing, online status |
| Deployment | Fly.io | Persistent connections, WebSocket-friendly |

**Arsitektur Real-Time**:
```
Client ──WebSocket──> Socket.io Server ──> Redis Pub/Sub ──> Broadcast
                          │
                          └──> PostgreSQL (persist messages)

Presence Flow:
User connect → SET user:${id}:online 1 EX 30 → heartbeat every 20s
User disconnect → DEL user:${id}:online
```

**Code Pattern Real-Time**:
```typescript
// server/socket/chat.handler.ts
export function registerChatHandlers(
  io: Server,
  socket: Socket,
  redis: Redis
) {
  socket.on('room:join', async ({ roomId }) => {
    await socket.join(roomId)
    
    // Set presence
    await redis.setex(`presence:${socket.data.userId}`, 30, roomId)
    
    // Broadcast ke room
    socket.to(roomId).emit('user:joined', {
      userId: socket.data.userId,
      timestamp: Date.now(),
    })
  })

  socket.on('message:send', async ({ roomId, content }) => {
    // 1. Persist ke DB
    const message = await db.insert(messages).values({
      roomId,
      senderId: socket.data.userId,
      content,
    }).returning()

    // 2. Broadcast ke semua member room
    io.to(roomId).emit('message:new', message[0])
  })

  socket.on('typing:start', ({ roomId }) => {
    socket.to(roomId).emit('typing:update', {
      userId: socket.data.userId,
      isTyping: true,
    })
  })
}
```

---

### 1.5 Project Type 5: Landing Page / Marketing

**Kapan**: Product launch, portfolio, campaign page, company website.

**Stack Optimal**:

| Layer | Pilihan | Alasan |
|---|---|---|
| Framework | Next.js (SSG) | Static generation = blazing fast |
| CMS | Sanity / Contentful / Notion API | Non-dev bisa edit |
| Animation | Framer Motion + GSAP | Smooth, cinematic |
| Analytics | Plausible / Vercel Analytics | Privacy-first |
| Forms | Resend + React Hook Form | Contact forms |
| Deployment | Vercel | Best-in-class CDN untuk static |

**Performance Checklist Landing Page**:
- [ ] LCP < 2.5s (optimize hero image, use `next/image`)
- [ ] CLS < 0.1 (define image dimensions, skeleton loading)
- [ ] FID < 100ms (minimize JavaScript)
- [ ] Font: `next/font` dengan `display: swap`
- [ ] Images: WebP/AVIF, lazy loading below-fold

---

### 1.6 Project Type 6: Dashboard / Admin Panel

**Kapan**: Internal tools, analytics dashboard, CMS backend, admin panel.

**Stack Optimal**:

| Layer | Pilihan | Alasan |
|---|---|---|
| Frontend | Next.js App Router | Structure yang solid |
| UI Library | shadcn/ui + Tremor | Data-dense UI components |
| Charts | Recharts / Nivo | Highly customizable |
| Tables | TanStack Table v8 | Server-side pagination, sorting, filtering |
| DB | PostgreSQL + ClickHouse | Transactional + analytics |
| Auth | Clerk / Auth.js | SSO support penting untuk admin |

---

## 2. MONOREPO ARCHITECTURE

### 2.1 Kapan Pakai Monorepo?

```
✅ Pakai monorepo ketika:
- Ada code sharing antara multiple apps (UI library, types, utils)
- Tim > 3 orang dengan roles berbeda
- Ada > 2 deployable units

❌ Skip monorepo ketika:
- Solo project sederhana
- Dua apps yang totally unrelated
- Tim belum familiar dengan tooling
```

### 2.2 Turborepo Setup

```
my-platform/
├── apps/
│   ├── web/                    # Next.js main app
│   │   ├── package.json
│   │   └── ...
│   ├── api/                    # Fastify backend
│   │   ├── package.json
│   │   └── ...
│   ├── admin/                  # Admin panel
│   │   ├── package.json
│   │   └── ...
│   └── docs/                   # Documentation (Nextra/Fumadocs)
│       ├── package.json
│       └── ...
│
├── packages/
│   ├── ui/                     # Shared component library
│   │   ├── src/
│   │   │   ├── button.tsx
│   │   │   └── index.ts        # Barrel exports
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── db/                     # Drizzle schema + client
│   │   ├── src/
│   │   │   ├── schema/
│   │   │   │   ├── users.ts
│   │   │   │   ├── products.ts
│   │   │   │   └── index.ts
│   │   │   ├── migrations/
│   │   │   └── client.ts
│   │   ├── drizzle.config.ts
│   │   └── package.json
│   ├── validators/             # Zod schemas shared FE+BE
│   │   ├── src/
│   │   │   ├── user.ts
│   │   │   └── index.ts
│   │   └── package.json
│   ├── auth/                   # Auth utilities
│   │   ├── src/
│   │   │   ├── middleware.ts
│   │   │   └── tokens.ts
│   │   └── package.json
│   └── config/                 # Shared configs
│       ├── eslint/
│       │   └── index.js
│       ├── tsconfig/
│       │   ├── base.json
│       │   ├── nextjs.json
│       │   └── node.json
│       └── package.json
│
├── turbo.json
├── package.json                # Root package.json (workspaces)
└── pnpm-workspace.yaml
```

**turbo.json**:
```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["$TURBO_DEFAULT$", ".env*"],
      "outputs": [".next/**", "!.next/cache/**", "dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^lint"]
    },
    "typecheck": {
      "dependsOn": ["^typecheck"]
    },
    "test": {
      "dependsOn": ["^build"]
    },
    "db:migrate": {
      "cache": false
    }
  }
}
```

**Shared package.json pattern (packages/ui)**:
```json
{
  "name": "@myapp/ui",
  "version": "0.0.0",
  "private": true,
  "exports": {
    ".": "./src/index.ts",
    "./button": "./src/button.tsx"
  },
  "devDependencies": {
    "@myapp/config": "workspace:*",
    "react": "catalog:"
  }
}
```

---

## 3. DOMAIN-DRIVEN DESIGN (DDD) UNTUK WEB

### 3.1 Kapan DDD Worth It?

```
✅ DDD masuk akal ketika:
- Business domain complex (multi-tenant, complex pricing, compliance)
- Tim > 5 orang, multiple teams
- Produk expected tumbuh significantly

❌ DDD overkill ketika:
- CRUD app sederhana
- MVP / early stage
- Solo project
```

### 3.2 Bounded Contexts

Pisahkan domain jadi bounded contexts yang independent:

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│    AUTH     │   │   BILLING   │   │   CATALOG   │   │   ORDERS    │
│             │   │             │   │             │   │             │
│ User        │   │ Subscription│   │ Product     │   │ Order       │
│ Session     │   │ Invoice     │   │ Category    │   │ OrderItem   │
│ Permission  │   │ Payment     │   │ Inventory   │   │ Shipment    │
└─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘
      │                   │                 │                  │
      └───────────────────┴─────────────────┴──────────────────┘
                          Shared Kernel (minimal)
                          - UserId (value object)
                          - Money (value object)
                          - Email (value object)
```

### 3.3 Aggregate Roots, Entities, Value Objects

```typescript
// Value Objects — immutable, no identity
class Money {
  constructor(
    public readonly amount: number,
    public readonly currency: 'USD' | 'IDR' | 'EUR'
  ) {
    if (amount < 0) throw new Error('Money cannot be negative')
  }

  add(other: Money): Money {
    if (this.currency !== other.currency) throw new Error('Currency mismatch')
    return new Money(this.amount + other.amount, this.currency)
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency
  }
}

// Entity — has identity
class OrderItem {
  constructor(
    public readonly id: string,         // Identity
    public readonly productId: string,
    public quantity: number,
    public readonly unitPrice: Money,
  ) {}

  get subtotal(): Money {
    return new Money(this.unitPrice.amount * this.quantity, this.unitPrice.currency)
  }
}

// Aggregate Root — controls access ke entities di dalamnya
class Order {
  private _items: OrderItem[] = []
  private _status: OrderStatus = 'pending'

  constructor(
    public readonly id: string,
    public readonly customerId: string,
    private readonly createdAt: Date = new Date()
  ) {}

  addItem(productId: string, quantity: number, unitPrice: Money): void {
    // Business rule: max 50 items per order
    if (this._items.length >= 50) {
      throw new Error('Order cannot have more than 50 items')
    }

    const existing = this._items.find(i => i.productId === productId)
    if (existing) {
      existing.quantity += quantity
    } else {
      this._items.push(new OrderItem(crypto.randomUUID(), productId, quantity, unitPrice))
    }
  }

  confirm(): void {
    if (this._status !== 'pending') {
      throw new Error(`Cannot confirm order in ${this._status} status`)
    }
    if (this._items.length === 0) {
      throw new Error('Cannot confirm empty order')
    }
    this._status = 'confirmed'
    // Domain event — emit ini ke EventBus
    // this.domainEvents.push(new OrderConfirmedEvent(this.id))
  }

  get total(): Money {
    return this._items.reduce(
      (sum, item) => sum.add(item.subtotal),
      new Money(0, 'USD')
    )
  }

  get items(): readonly OrderItem[] { return this._items }
  get status(): OrderStatus { return this._status }
}
```

### 3.4 Repository Pattern

```typescript
// Abstraksi — business logic gak tau database-nya apa
interface IOrderRepository {
  findById(id: string): Promise<Order | null>
  findByCustomerId(customerId: string): Promise<Order[]>
  save(order: Order): Promise<void>
  delete(id: string): Promise<void>
}

// Implementasi konkret (bisa diganti kalau pindah DB)
class DrizzleOrderRepository implements IOrderRepository {
  constructor(private readonly db: DrizzleDB) {}

  async findById(id: string): Promise<Order | null> {
    const row = await this.db.query.orders.findFirst({
      where: eq(orders.id, id),
      with: { items: true },
    })
    if (!row) return null
    return this.toDomain(row)
  }

  async save(order: Order): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx.insert(orders).values(this.toRow(order))
        .onConflictDoUpdate({ target: orders.id, set: this.toRow(order) })
      // Sync items...
    })
  }

  private toDomain(row: OrderRow): Order {
    // Map DB row → Domain object
    const order = new Order(row.id, row.customerId, row.createdAt)
    // ... reconstruct items
    return order
  }
}
```

---

## 4. DESIGN PATTERNS FULLSTACK

### 4.1 Frontend Patterns

**Container / Presenter (Smart / Dumb Components)**:
```typescript
// Presenter — pure UI, no data fetching
function UserCardPresenter({
  name, email, avatarUrl, onFollow
}: UserCardProps) {
  return (
    <div className="card">
      <img src={avatarUrl} alt={name} />
      <h3>{name}</h3>
      <p>{email}</p>
      <button onClick={onFollow}>Follow</button>
    </div>
  )
}

// Container — data + business logic
function UserCardContainer({ userId }: { userId: string }) {
  const { data: user, isLoading } = useUser(userId)
  const followMutation = useFollowUser()

  if (isLoading) return <UserCardSkeleton />
  if (!user) return null

  return (
    <UserCardPresenter
      {...user}
      onFollow={() => followMutation.mutate(userId)}
    />
  )
}
```

**Compound Components Pattern**:
```typescript
// Parent manages shared state
const Dialog = ({ children, open, onOpenChange }: DialogProps) => {
  return (
    <DialogContext.Provider value={{ open, onOpenChange }}>
      {children}
    </DialogContext.Provider>
  )
}

Dialog.Trigger = function DialogTrigger({ children }: { children: ReactNode }) {
  const { onOpenChange } = useDialogContext()
  return <button onClick={() => onOpenChange(true)}>{children}</button>
}

Dialog.Content = function DialogContent({ children }: { children: ReactNode }) {
  const { open } = useDialogContext()
  if (!open) return null
  return <div className="dialog-content">{children}</div>
}

// Usage — composable, no prop drilling
<Dialog open={open} onOpenChange={setOpen}>
  <Dialog.Trigger>Open</Dialog.Trigger>
  <Dialog.Content>
    <p>Dialog body</p>
  </Dialog.Content>
</Dialog>
```

**Custom Hooks untuk Logic Reuse**:
```typescript
// hooks/use-infinite-scroll.ts
export function useInfiniteScroll<T>(
  fetcher: (cursor: string | null) => Promise<{ items: T[]; nextCursor: string | null }>
) {
  const [items, setItems] = useState<T[]>([])
  const [cursor, setCursor] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [hasMore, setHasMore] = useState(true)

  const loadMore = async () => {
    if (isLoading || !hasMore) return
    setIsLoading(true)
    const result = await fetcher(cursor)
    setItems(prev => [...prev, ...result.items])
    setCursor(result.nextCursor)
    setHasMore(result.nextCursor !== null)
    setIsLoading(false)
  }

  return { items, loadMore, isLoading, hasMore }
}
```

### 4.2 Backend Patterns

**Service Layer Pattern**:
```typescript
// Service — business logic, tidak tau HTTP/WebSocket
class UserService {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly emailService: EmailService,
    private readonly eventBus: EventBus,
  ) {}

  async register(input: RegisterInput): Promise<User> {
    // 1. Validate business rules
    const existing = await this.userRepo.findByEmail(input.email)
    if (existing) throw new ConflictError('Email already registered')

    // 2. Hash password
    const hashedPassword = await bcrypt.hash(input.password, 12)

    // 3. Create user
    const user = await this.userRepo.create({
      ...input,
      password: hashedPassword,
    })

    // 4. Side effects (via events — decoupled)
    await this.eventBus.emit('user.registered', { userId: user.id, email: user.email })

    return user
  }
}

// Route handler — only HTTP concerns
app.post('/register', async (req, reply) => {
  const user = await userService.register(req.body)
  return reply.status(201).send({ id: user.id, email: user.email })
})
```

**CQRS — Kapan Worth It?**:
```
CQRS = Command Query Responsibility Segregation
Command = mutations (write)
Query = reads

Worth it ketika:
✅ Read dan write models significantly berbeda
✅ Performance optimization needed (read replicas)
✅ Event sourcing diimplementasikan

JANGAN pake CQRS kalau:
❌ Simple CRUD
❌ Tim belum familiar, complexity meningkat drastis
❌ Tidak ada performance problem yang clear
```

**Event-Driven Architecture**:
```typescript
// Decoupled side effects via EventEmitter
class EventBus {
  private emitter = new EventEmitter()

  emit<T>(event: string, payload: T): void {
    this.emitter.emit(event, payload)
  }

  on<T>(event: string, handler: (payload: T) => Promise<void>): void {
    this.emitter.on(event, async (payload) => {
      try {
        await handler(payload)
      } catch (err) {
        logger.error({ event, err }, 'Event handler failed')
      }
    })
  }
}

// Registration
eventBus.on('user.registered', async ({ userId, email }) => {
  await emailService.sendWelcome(email)
})

eventBus.on('user.registered', async ({ userId }) => {
  await analyticsService.track('user_registered', { userId })
})
```

---

## 5. API CONTRACTS & TYPE SHARING

### 5.1 tRPC — End-to-End Type Safety

**Kapan pakai tRPC**: Monorepo, full-stack Next.js, team yang sama handle FE+BE.

```typescript
// server/trpc/router.ts
import { z } from 'zod'
import { router, protectedProcedure, publicProcedure } from './trpc'

export const userRouter = router({
  me: protectedProcedure.query(async ({ ctx }) => {
    return ctx.db.query.users.findFirst({
      where: eq(users.id, ctx.session.userId),
    })
  }),

  update: protectedProcedure
    .input(z.object({
      name: z.string().min(2).max(100).optional(),
      bio: z.string().max(500).optional(),
    }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.update(users)
        .set(input)
        .where(eq(users.id, ctx.session.userId))
        .returning()
    }),
})

// client — fully typed, no manual type definition
const { data: user } = api.user.me.useQuery()
//        ^^ inferred type dari server
```

### 5.2 Zod sebagai Single Source of Truth

```typescript
// packages/validators/src/user.ts
// Ini bisa di-import dari BOTH frontend dan backend
import { z } from 'zod'

export const RegisterSchema = z.object({
  email: z.string().email('Invalid email'),
  password: z
    .string()
    .min(8, 'Min 8 characters')
    .regex(/[A-Z]/, 'Must contain uppercase')
    .regex(/[0-9]/, 'Must contain number'),
  name: z.string().min(2).max(100),
})

export type RegisterInput = z.infer<typeof RegisterSchema>

// Frontend — form validation
const form = useForm<RegisterInput>({
  resolver: zodResolver(RegisterSchema),
})

// Backend — request validation
app.post('/register', async (req, reply) => {
  const input = RegisterSchema.parse(req.body) // throws ZodError if invalid
  // ...
})
```

### 5.3 OpenAPI + Code Generation

**Kapan**: Public API, multiple consumers, strict versioning.

```yaml
# openapi.yaml
openapi: 3.0.0
info:
  title: My API
  version: 1.0.0
paths:
  /users/{id}:
    get:
      operationId: getUserById
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
```

```bash
# Generate TypeScript types dari OpenAPI spec
npx openapi-typescript openapi.yaml -o src/types/api.d.ts

# Generate typed client dengan orval
npx orval --config orval.config.ts
```

---

## 6. DATABASE MIGRATION STRATEGY

### 6.1 Zero-Downtime Migration Pattern

Ini penting banget buat production. Jangan pernah drop column langsung!

**Expand-Migrate-Contract (3 deployment cycle)**:

```
Deploy 1: EXPAND
- Tambah column baru (nullable)
- Code bisa baca dua-duanya

Deploy 2: MIGRATE
- Backfill data ke column baru
- Validasi data integrity

Deploy 3: CONTRACT
- Update code pakai column baru exclusively
- Remove column lama
```

**Contoh Nyata — rename column `user_name` → `display_name`**:

```sql
-- Migration 1: EXPAND
ALTER TABLE users ADD COLUMN display_name VARCHAR(100);
UPDATE users SET display_name = user_name; -- backfill

-- Deploy code yang support keduanya
-- Code: name = display_name ?? user_name

-- Migration 2: CONTRACT (setelah semua app instances ter-update)
ALTER TABLE users DROP COLUMN user_name;
```

### 6.2 Drizzle ORM Migration

```typescript
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  schema: './src/lib/db/schema.ts',
  out: './drizzle/migrations',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
})
```

```bash
# Development — push schema changes langsung (skip migration files)
pnpm drizzle-kit push

# Production — generate migration files, review, then apply
pnpm drizzle-kit generate
pnpm drizzle-kit migrate

# CI/CD pipeline
pnpm drizzle-kit migrate --config drizzle.config.ts
```

### 6.3 Drizzle Schema Patterns

```typescript
// lib/db/schema/users.ts
import { pgTable, text, timestamp, boolean, pgEnum } from 'drizzle-orm/pg-core'

export const userRoleEnum = pgEnum('user_role', ['user', 'admin', 'moderator'])

export const users = pgTable('users', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  email: text('email').notNull().unique(),
  name: text('name').notNull(),
  role: userRoleEnum('role').default('user').notNull(),
  emailVerified: boolean('email_verified').default(false).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull().$onUpdate(() => new Date()),
})

// Relations
export const usersRelations = relations(users, ({ many }) => ({
  posts: many(posts),
  subscriptions: many(subscriptions),
}))

// Inferred types
export type User = typeof users.$inferSelect
export type NewUser = typeof users.$inferInsert
```

---

## 7. ENVIRONMENT MANAGEMENT

### 7.1 Validated Environment Variables

Jangan pernah access `process.env` langsung. Validasi dulu.

```typescript
// lib/env.ts
import { z } from 'zod'

const envSchema = z.object({
  // Node
  NODE_ENV: z.enum(['development', 'test', 'staging', 'production']),

  // Database
  DATABASE_URL: z.string().url().startsWith('postgresql://'),

  // Auth
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 chars'),
  NEXTAUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),

  // Third-party
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
  STRIPE_WEBHOOK_SECRET: z.string().startsWith('whsec_'),
  RESEND_API_KEY: z.string().startsWith('re_'),

  // Redis (optional in dev)
  REDIS_URL: z.string().url().optional(),

  // Public env (exposed to client)
  NEXT_PUBLIC_APP_URL: z.string().url(),
  NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY: z.string().startsWith('pk_'),
})

// Throws at startup if missing/invalid — fail fast
export const env = envSchema.parse(process.env)

// Usage anywhere
import { env } from '@/lib/env'
const stripe = new Stripe(env.STRIPE_SECRET_KEY)
```

### 7.2 Multi-Environment Setup

```bash
.env.local          # Local dev only, gitignored
.env.development    # Shared dev defaults (can be in git, no secrets)
.env.test           # Test environment
.env.staging        # Staging (managed by CI/deployment platform)
.env.production     # Production (managed by deployment platform)
.env.example        # Template dengan semua keys (IN GIT, no values)
```

**.env.example**:
```bash
# App
NODE_ENV=development
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/myapp

# Auth
NEXTAUTH_SECRET=generate-with-openssl-rand-base64-32
NEXTAUTH_URL=http://localhost:3000
JWT_SECRET=generate-with-openssl-rand-base64-32

# Stripe
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...

# Email
RESEND_API_KEY=re_...

# Redis
REDIS_URL=redis://localhost:6379
```

**CRITICAL**: `NEXT_PUBLIC_` prefix = exposed ke browser. Jangan taruh secrets di sana!

---

## 8. STARTER TEMPLATES ANALYSIS

### 8.1 create-t3-app

```bash
pnpm create t3-app@latest
```

**What's included**:
- Next.js (App Router)
- TypeScript
- Tailwind CSS
- tRPC
- Prisma
- NextAuth
- Zod (via tRPC)

**Kapan pakai**: Lo butuh type-safe full-stack cepat, team familiar sama tRPC.

**Kekurangan**: Prisma lebih berat dari Drizzle, tRPC butuh learning curve.

### 8.2 create-next-app

```bash
pnpm create next-app@latest --typescript --tailwind --app --src-dir
```

**What's included**: Literally cuma Next.js. Clean slate.

**Kapan pakai**: Lo tau persis stack lo sendiri, prefer minimal setup.

### 8.3 Analisis Starter Komersial

| Starter | Included | Harga | Worth It? |
|---|---|---|---|
| ShipFast | Next.js + Stripe + NextAuth + Resend + Crisp + MongoDB | $199 | Worth it kalau mau launch cepat |
| Supastarter | Next.js + Supabase + Stripe + i18n + Lemon | $199-299 | Lebih complete, i18n support |
| Makerkit | Next.js + Firebase/Supabase + Stripe + Inngest | $299 | Multi-provider DB |

**Rekomendasi**:
- MVP / early startup → pakai starter komersial
- Belajar / portfolio → bikin dari scratch
- Production serious → dari scratch dengan pilihan stack sendiri

---

## 9. PEMBAYARAN & MONETISASI

### 9.1 Stripe Full Integration

**Setup flow**:
```typescript
// lib/stripe/client.ts
import Stripe from 'stripe'
import { env } from '@/lib/env'

export const stripe = new Stripe(env.STRIPE_SECRET_KEY, {
  apiVersion: '2024-06-20',
  typescript: true,
})
```

**Checkout Session (Hosted — recommended untuk simplicity)**:
```typescript
// server/actions/billing.actions.ts
'use server'

export async function createCheckoutSession(priceId: string) {
  const session = await getCurrentSession() // Get auth session
  if (!session) throw new Error('Unauthorized')

  const user = await getUserWithStripeId(session.userId)

  const checkoutSession = await stripe.checkout.sessions.create({
    customer: user.stripeCustomerId ?? undefined,
    customer_email: !user.stripeCustomerId ? user.email : undefined,
    mode: 'subscription',
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${env.NEXT_PUBLIC_APP_URL}/dashboard?checkout=success`,
    cancel_url: `${env.NEXT_PUBLIC_APP_URL}/pricing`,
    subscription_data: {
      trial_period_days: 14,
      metadata: { userId: session.userId },
    },
    allow_promotion_codes: true,
  })

  redirect(checkoutSession.url!)
}
```

**Webhook Handler** — ini critical, harus secure:
```typescript
// app/api/webhooks/stripe/route.ts
import { NextRequest } from 'next/server'
import { stripe } from '@/lib/stripe/client'
import { env } from '@/lib/env'

export async function POST(req: NextRequest) {
  const body = await req.text()
  const signature = req.headers.get('stripe-signature')!

  let event: Stripe.Event

  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      env.STRIPE_WEBHOOK_SECRET
    )
  } catch (err) {
    return new Response('Webhook signature verification failed', { status: 400 })
  }

  // Handle events
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session
      await handleCheckoutComplete(session)
      break
    }

    case 'customer.subscription.updated': {
      const subscription = event.data.object as Stripe.Subscription
      await handleSubscriptionUpdate(subscription)
      break
    }

    case 'customer.subscription.deleted': {
      const subscription = event.data.object as Stripe.Subscription
      await handleSubscriptionCancel(subscription)
      break
    }

    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice
      await handlePaymentFailed(invoice)
      break
    }
  }

  return new Response(null, { status: 200 })
}

async function handleCheckoutComplete(session: Stripe.Checkout.Session) {
  const userId = session.subscription_data?.metadata?.userId
  if (!userId) return

  const subscription = await stripe.subscriptions.retrieve(
    session.subscription as string
  )

  await db.update(users).set({
    stripeCustomerId: session.customer as string,
    stripeSubscriptionId: subscription.id,
    stripePriceId: subscription.items.data[0].price.id,
    stripeCurrentPeriodEnd: new Date(subscription.current_period_end * 1000),
    plan: 'pro',
  }).where(eq(users.id, userId))
}
```

**Customer Portal** (self-service subscription management):
```typescript
export async function createPortalSession() {
  const session = await getCurrentSession()
  const user = await getUserById(session!.userId)

  const portalSession = await stripe.billingPortal.sessions.create({
    customer: user.stripeCustomerId!,
    return_url: `${env.NEXT_PUBLIC_APP_URL}/settings/billing`,
  })

  redirect(portalSession.url)
}
```

### 9.2 Lemon Squeezy (Alternatif Lebih Simpel)

```
✅ Kelebihan LemonSqueezy vs Stripe:
- Merchant of record — pajak diurus mereka
- Setup lebih cepat
- Ideal untuk digital products, one-time purchases

❌ Kekurangan:
- Fee lebih tinggi (5% + $0.50)
- Less customizable
- Ecosystem lebih kecil
```

---

## 10. SEO & METADATA NEXT.JS

### 10.1 generateMetadata

```typescript
// app/products/[slug]/page.tsx
import type { Metadata } from 'next'

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const product = await getProductBySlug(params.slug)
  
  if (!product) return { title: 'Product Not Found' }

  return {
    title: product.name,
    description: product.shortDescription,
    keywords: product.tags,
    
    openGraph: {
      title: product.name,
      description: product.shortDescription,
      images: [
        {
          url: product.imageUrl,
          width: 1200,
          height: 630,
          alt: product.name,
        },
      ],
      type: 'website',
    },

    twitter: {
      card: 'summary_large_image',
      title: product.name,
      description: product.shortDescription,
      images: [product.imageUrl],
    },

    alternates: {
      canonical: `https://mysite.com/products/${params.slug}`,
    },
  }
}
```

### 10.2 Structured Data (JSON-LD)

```typescript
// components/structured-data.tsx
export function ProductStructuredData({ product }: { product: Product }) {
  const data = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    description: product.description,
    image: product.imageUrl,
    offers: {
      '@type': 'Offer',
      price: product.price,
      priceCurrency: 'USD',
      availability: product.inStock
        ? 'https://schema.org/InStock'
        : 'https://schema.org/OutOfStock',
      url: `https://mysite.com/products/${product.slug}`,
    },
    aggregateRating: product.rating ? {
      '@type': 'AggregateRating',
      ratingValue: product.rating.average,
      reviewCount: product.rating.count,
    } : undefined,
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  )
}
```

### 10.3 Sitemap & Robots

```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const products = await db.query.products.findMany({
    columns: { slug: true, updatedAt: true },
    where: eq(products.status, 'active'),
  })

  return [
    {
      url: 'https://mysite.com',
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 1,
    },
    ...products.map((p) => ({
      url: `https://mysite.com/products/${p.slug}`,
      lastModified: p.updatedAt,
      changeFrequency: 'weekly' as const,
      priority: 0.8,
    })),
  ]
}

// app/robots.ts
import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: ['/api/', '/admin/', '/dashboard/'],
    },
    sitemap: 'https://mysite.com/sitemap.xml',
  }
}
```

---

## 11. INTERNATIONALIZATION (i18n)

### 11.1 next-intl Setup

```bash
pnpm add next-intl
```

**File structure**:
```
messages/
├── en.json
├── id.json
└── ar.json          # RTL language

src/
├── i18n/
│   ├── routing.ts
│   └── request.ts
├── middleware.ts
└── app/
    └── [locale]/
        ├── layout.tsx
        └── page.tsx
```

**routing.ts**:
```typescript
// i18n/routing.ts
import { defineRouting } from 'next-intl/routing'

export const routing = defineRouting({
  locales: ['en', 'id', 'ar'],
  defaultLocale: 'en',
  pathnames: {
    '/': '/',
    '/products': {
      en: '/products',
      id: '/produk',
      ar: '/منتجات',
    },
  },
})
```

**middleware.ts**:
```typescript
import createMiddleware from 'next-intl/middleware'
import { routing } from './i18n/routing'

export default createMiddleware(routing)

export const config = {
  matcher: ['/((?!api|_next|.*\\..*).*)'],
}
```

**Translation files**:
```json
// messages/id.json
{
  "Navigation": {
    "home": "Beranda",
    "products": "Produk",
    "about": "Tentang Kami"
  },
  "Product": {
    "addToCart": "Tambah ke Keranjang",
    "inStock": "Tersedia",
    "outOfStock": "Habis",
    "price": "Harga: {price}",
    "reviewCount": "{count, plural, one {# ulasan} other {# ulasan}}"
  }
}
```

**Usage in component**:
```typescript
import { useTranslations, useFormatter } from 'next-intl'

export function ProductCard({ product }: { product: Product }) {
  const t = useTranslations('Product')
  const format = useFormatter()

  return (
    <div>
      <p>{t('price', { price: format.number(product.price, { style: 'currency', currency: 'USD' }) })}</p>
      <p>{t('reviewCount', { count: product.reviewCount })}</p>
      <button>{t('addToCart')}</button>
    </div>
  )
}
```

### 11.2 RTL Support

```css
/* CSS Logical Properties — works for both LTR dan RTL */
.card {
  padding-inline-start: 1rem;  /* padding-left di LTR, padding-right di RTL */
  padding-inline-end: 1rem;
  margin-block-start: 0.5rem;  /* margin-top */
  border-inline-start: 2px solid currentColor; /* left border di LTR */
}
```

```html
<!-- layout.tsx -->
<html lang={locale} dir={locale === 'ar' ? 'rtl' : 'ltr'}>
```

---

## 12. AUTHENTICATION FLOWS LENGKAP

### 12.1 Email + Password Flow

```
REGISTER:
1. User submit form (email, password, name)
2. Validate input (Zod)
3. Check email uniqueness
4. Hash password: bcrypt.hash(password, 12)
5. Create user (emailVerified: false)
6. Generate email verification token
7. Send verification email
8. Return success message

LOGIN:
1. User submit (email, password)
2. Find user by email
3. Compare: bcrypt.compare(password, hash)
4. Check emailVerified (optional — enforce or just warn)
5. Issue tokens:
   - Access token: JWT, 15min expiry, payload: { sub: userId, role }
   - Refresh token: opaque token, 30 days, stored in DB
6. Set HTTP-only cookies
7. Return user data (no tokens in body)

REFRESH TOKEN:
1. Read refresh token from HTTP-only cookie
2. Validate token in DB (not expired, not revoked)
3. Issue new access token
4. Rotate refresh token (optional security enhancement)

FORGOT PASSWORD:
1. User submit email
2. Always return same message (prevent email enumeration)
3. If user exists:
   a. Generate secure token: crypto.randomBytes(32).toString('hex')
   b. Hash token, store in DB with 1hr expiry
   c. Send email with: /reset-password?token=RAW_TOKEN
4. User clicks link → validate token against hashed version
5. If valid → allow new password
6. Invalidate token after use
```

**Implementation**:
```typescript
// server/services/auth.service.ts
import bcrypt from 'bcryptjs'
import { SignJWT, jwtVerify } from 'jose'
import crypto from 'crypto'

const JWT_SECRET = new TextEncoder().encode(env.JWT_SECRET)

export class AuthService {
  async login(email: string, password: string) {
    const user = await userRepo.findByEmail(email)
    if (!user) throw new UnauthorizedError('Invalid credentials')

    const passwordMatch = await bcrypt.compare(password, user.password)
    if (!passwordMatch) throw new UnauthorizedError('Invalid credentials')

    const accessToken = await new SignJWT({ sub: user.id, role: user.role })
      .setProtectedHeader({ alg: 'HS256' })
      .setExpirationTime('15m')
      .setIssuedAt()
      .sign(JWT_SECRET)

    const refreshToken = crypto.randomBytes(32).toString('hex')
    const hashedRefreshToken = crypto
      .createHash('sha256')
      .update(refreshToken)
      .digest('hex')

    await sessionRepo.create({
      userId: user.id,
      hashedToken: hashedRefreshToken,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    })

    return { accessToken, refreshToken }
  }

  async forgotPassword(email: string) {
    // Always resolve — never expose whether email exists
    const user = await userRepo.findByEmail(email)
    if (!user) return

    const rawToken = crypto.randomBytes(32).toString('hex')
    const hashedToken = crypto.createHash('sha256').update(rawToken).digest('hex')

    await passwordResetRepo.create({
      userId: user.id,
      hashedToken,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000), // 1 hour
    })

    await emailService.sendPasswordReset(user.email, rawToken)
  }

  async resetPassword(rawToken: string, newPassword: string) {
    const hashedToken = crypto.createHash('sha256').update(rawToken).digest('hex')
    
    const resetRecord = await passwordResetRepo.findValid(hashedToken)
    if (!resetRecord) throw new UnauthorizedError('Invalid or expired token')

    const hashed = await bcrypt.hash(newPassword, 12)
    await userRepo.updatePassword(resetRecord.userId, hashed)
    await passwordResetRepo.invalidate(resetRecord.id)
    
    // Optionally revoke all sessions
    await sessionRepo.revokeAll(resetRecord.userId)
  }
}
```

### 12.2 Magic Link (Passwordless)

```typescript
export async function sendMagicLink(email: string) {
  const user = await userRepo.findOrCreate(email)
  
  const token = crypto.randomBytes(32).toString('hex')
  const hashedToken = crypto.createHash('sha256').update(token).digest('hex')
  
  await magicLinkRepo.create({
    userId: user.id,
    hashedToken,
    expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 minutes
  })

  const url = `${env.NEXT_PUBLIC_APP_URL}/auth/verify?token=${token}&email=${email}`
  await emailService.sendMagicLink(email, url)
}

export async function verifyMagicLink(token: string, email: string) {
  const hashedToken = crypto.createHash('sha256').update(token).digest('hex')
  const record = await magicLinkRepo.findValid(hashedToken)
  
  if (!record) throw new UnauthorizedError('Invalid or expired magic link')
  
  const user = await userRepo.findById(record.userId)
  if (user.email !== email) throw new UnauthorizedError('Email mismatch')
  
  await magicLinkRepo.invalidate(record.id)
  await userRepo.markEmailVerified(user.id)
  
  return await createSession(user)
}
```

### 12.3 TOTP / OTP (Multi-Factor Authentication)

```typescript
import { TOTP } from 'otpauth'

export async function enableMFA(userId: string) {
  const secret = new TOTP({
    issuer: 'MyApp',
    label: userId,
    algorithm: 'SHA1',
    digits: 6,
    period: 30,
    secret: OTPAuth.Secret.generate()
  })

  // Store secret (encrypted) in DB
  await userRepo.updateMFASecret(userId, secret.secret.base32)

  // Return QR code URI for authenticator app
  return secret.toString() // otpauth:// URI
}

export async function verifyTOTP(userId: string, code: string): Promise<boolean> {
  const user = await userRepo.findById(userId)
  if (!user.mfaSecret) return false

  const totp = new TOTP({
    algorithm: 'SHA1',
    digits: 6,
    period: 30,
    secret: user.mfaSecret,
  })

  const delta = totp.validate({ token: code, window: 1 })
  return delta !== null
}
```

### 12.4 Auth.js v5 (NextAuth) Setup Lengkap

```typescript
// lib/auth/config.ts
import NextAuth from 'next-auth'
import Credentials from 'next-auth/providers/credentials'
import GitHub from 'next-auth/providers/github'
import { DrizzleAdapter } from '@auth/drizzle-adapter'
import { db } from '@/lib/db/client'

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: DrizzleAdapter(db),
  
  session: { strategy: 'jwt' },
  
  pages: {
    signIn: '/login',
    error: '/auth/error',
  },

  providers: [
    GitHub({
      clientId: env.GITHUB_CLIENT_ID,
      clientSecret: env.GITHUB_CLIENT_SECRET,
    }),

    Credentials({
      async authorize(credentials) {
        const parsed = LoginSchema.safeParse(credentials)
        if (!parsed.success) return null

        const user = await authService.validateCredentials(
          parsed.data.email,
          parsed.data.password
        )
        return user
      },
    }),
  ],

  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.role = user.role
        token.subscriptionTier = user.subscriptionTier
      }
      return token
    },

    async session({ session, token }) {
      session.user.id = token.sub!
      session.user.role = token.role as string
      session.user.subscriptionTier = token.subscriptionTier as string
      return session
    },
  },
})
```

---

## 13. PERFORMANCE PATTERNS

### 13.1 React Server Components Strategy

```
Rule: Server Component by default, Client Component ketika butuh:
- useState / useReducer
- useEffect
- Browser APIs (window, localStorage)
- Event listeners
- Third-party client libs yang butuh browser

Marking:
- Default (no directive) = Server Component
- 'use client' at top = Client Component
- 'use server' = Server Action
```

```
App Layout (Server)
  ├── Header (Server — data fetching)
  │     └── UserAvatar (Client — dropdown interaction)
  ├── Sidebar (Server — nav links)
  └── Main Content (Server)
        ├── ProductList (Server — data fetching)
        └── AddToCartButton (Client — onClick + useState)
```

### 13.2 Caching Strategy Next.js

```typescript
// Fetch dengan revalidation
const data = await fetch('https://api.example.com/data', {
  next: { revalidate: 3600 }, // Cache 1 jam
})

// No cache (always fresh)
const data = await fetch('https://api.example.com/data', {
  cache: 'no-store',
})

// Tag-based revalidation (on demand)
const data = await fetch('https://api.example.com/products', {
  next: { tags: ['products'] },
})

// Invalidate from Server Action
import { revalidateTag } from 'next/cache'
export async function updateProduct(id: string, data: ProductInput) {
  await db.update(products).set(data).where(eq(products.id, id))
  revalidateTag('products') // Invalidate all fetches with tag 'products'
}
```

### 13.3 Database Query Optimization

```typescript
// ❌ N+1 Problem
const orders = await db.query.orders.findMany()
for (const order of orders) {
  // N queries — satu per order
  const user = await db.query.users.findFirst({ where: eq(users.id, order.userId) })
}

// ✅ Single query dengan join
const ordersWithUsers = await db.query.orders.findMany({
  with: { user: true }, // Drizzle handles JOIN
  limit: 20,
})

// ✅ Pagination dengan cursor (lebih efficient dari OFFSET)
const { cursor } = req.query
const items = await db.query.products.findMany({
  where: cursor ? gt(products.id, cursor) : undefined,
  orderBy: asc(products.id),
  limit: 21, // Fetch 21, kalau ada ke-21 berarti ada next page
})
const nextCursor = items.length > 20 ? items[20].id : null
const data = items.slice(0, 20)
```

---

## 14. QUICK DECISION REFERENCE

### Stack Decision Matrix

```
Pertanyaan                        Jawaban → Stack
─────────────────────────────────────────────────────
Butuh SSR / SEO?                  YES → Next.js | NO → Vite SPA
Ada multiple apps?                YES → Turborepo monorepo
High-traffic API?                 YES → Fastify standalone | NO → Next.js Route Handlers
Real-time features?               YES → Socket.io + Redis adapter
E-commerce?                       YES → ISR + Redis cart + Meilisearch
Type safety FE-BE?                YES → tRPC (internal) | OpenAPI (public)
Multi-language?                   YES → next-intl
Payments?                         Stripe (complex) | LemonSqueezy (simple)
Auth complexity low?              Auth.js | Clerk (zero-config)
Auth complexity high?             Custom JWT + bcrypt
Analytics heavy?                  ClickHouse + PostgreSQL split
File uploads?                     Cloudflare R2 (cheap) | AWS S3 (ecosystem)
Email?                            Resend + React Email
```

### Deployment Decision

```
Frontend only (static)    → Vercel (gratis, zero-config)
Full-stack Next.js        → Vercel (best DX)
API/Backend               → Railway (easy) | Fly.io (WS-friendly) | AWS ECS (enterprise)
Database                  → Neon (serverless PG) | Supabase (PG + extras) | PlanetScale (MySQL)
Redis                     → Upstash (serverless) | Railway Redis | ElastiCache
File storage              → Cloudflare R2 (cheapest egress) | AWS S3 (ecosystem)
```

---

## 15. COMMON MISTAKES & PITFALLS

```
❌ Putting secrets in NEXT_PUBLIC_ env vars
✅ NEXT_PUBLIC_ only for public values (URLs, publishable keys)

❌ Fetching in useEffect for initial data
✅ Use TanStack Query atau RSC untuk data fetching

❌ Storing JWT in localStorage
✅ HTTP-only cookies — tidak accessible dari JavaScript

❌ Direct DB access dari Client Components
✅ Route Handlers / Server Actions sebagai intermediary

❌ No input validation on server (trust frontend validation only)
✅ ALWAYS validate input di server, Zod parse sebelum DB

❌ Storing raw passwords
✅ bcrypt hash dengan cost factor 12+

❌ DROP COLUMN in production directly
✅ Expand-Migrate-Contract pattern

❌ process.env.SOME_VAR tanpa validasi
✅ Zod envSchema.parse() di startup

❌ Over-engineering dengan CQRS/EventSourcing di MVP
✅ Simple service layer dulu, evolve ketika benar-benar butuh

❌ Waterfall data fetching (sequential awaits)
✅ Promise.all() untuk parallel fetches

❌ Monolith langsung dari awal dengan 10+ microservices
✅ Modular monolith dulu, extract ke services kalau traffic demand
```

---

*Bxploit Architecture Knowledge Base — Built for pentest-grade production apps*
*Total: 800+ lines substantive content*
