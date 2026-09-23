# ⚡ REALTIME, WEBSOCKET, SSE & ADVANCED API PATTERNS — Bxploit Knowledge Base
**Version:** 1.0.0 | **Category:** Realtime Engineering & API Design

---

## 1. WEBSOCKET DEEP DIVE

### Kapan Pakai WebSocket vs SSE vs HTTP Polling?
```
USE WEBSOCKET ketika:
  ✅ Bidirectional communication (chat, collaborative editing, gaming)
  ✅ High-frequency updates (trading, live sports, cursor tracking)
  ✅ Low latency critical (real-time games, live collaboration)

USE SSE (Server-Sent Events) ketika:
  ✅ Server → Client only (notifications, feed updates, progress bars)
  ✅ Perlu CDN/proxy support (SSE lebih CDN-friendly)
  ✅ Reconnect otomatis built-in (SSE has native reconnect)
  ✅ HTTP/2 multiplexing (lebih efisien dari WebSocket di HTTP/2)

USE LONG POLLING ketika:
  ✅ Environment tidak support WebSocket (korporat proxy)
  ✅ Infrequent updates (check setiap 30s)
  ⚠️ Overhead lebih tinggi dari SSE/WebSocket

USE HTTP STREAMING ketika:
  ✅ Large file streaming, AI response streaming (ChatGPT style)
```

### Socket.io Full Implementation
```typescript
// server/socket.ts
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';

export async function initSocket(httpServer: HTTPServer) {
  // Redis adapter untuk horizontal scaling (multiple Node.js instances)
  const pubClient = createClient({ url: process.env.REDIS_URL });
  const subClient = pubClient.duplicate();
  await Promise.all([pubClient.connect(), subClient.connect()]);

  const io = new Server(httpServer, {
    cors: {
      origin: process.env.CORS_ORIGIN,
      credentials: true,
    },
    transports: ['websocket', 'polling'], // websocket preferred, polling fallback
    pingTimeout: 60000,
    pingInterval: 25000,
  });

  // Gunakan Redis adapter untuk scale-out
  io.adapter(createAdapter(pubClient, subClient));

  // Authentication middleware
  io.use(async (socket, next) => {
    const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
    if (!token) return next(new Error('Authentication required'));
    
    try {
      const payload = verifyAccessToken(token);
      socket.data.userId = payload.sub;
      socket.data.user = await db.user.findUnique({ where: { id: payload.sub } });
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.data.userId;
    console.log(`User ${userId} connected — socket: ${socket.id}`);
    
    // Join personal room (untuk direct messages / notifications)
    socket.join(`user:${userId}`);
    
    // Update online presence
    redis.hset('online_users', userId, Date.now().toString());
    io.emit('presence:update', { userId, status: 'online' });

    // Join chat room
    socket.on('room:join', async (roomId: string) => {
      const hasAccess = await checkRoomAccess(userId, roomId);
      if (!hasAccess) return socket.emit('error', { code: 'FORBIDDEN', message: 'No access to room' });
      
      await socket.join(`room:${roomId}`);
      socket.to(`room:${roomId}`).emit('room:user_joined', { userId, roomId });
      socket.emit('room:joined', { roomId });
    });

    // Send message
    socket.on('message:send', async (data: { roomId: string; content: string; type: 'text' | 'image' }) => {
      // Validate
      if (!data.content?.trim() || data.content.length > 4096) {
        return socket.emit('error', { code: 'INVALID_MESSAGE' });
      }
      
      // Check room membership
      if (!socket.rooms.has(`room:${data.roomId}`)) {
        return socket.emit('error', { code: 'NOT_IN_ROOM' });
      }
      
      // Persist to DB
      const message = await db.message.create({
        data: {
          roomId: data.roomId,
          senderId: userId,
          content: sanitize(data.content),
          type: data.type,
        },
        include: { sender: { select: { id: true, name: true, avatarUrl: true } } },
      });
      
      // Broadcast to room (including sender for confirmation)
      io.to(`room:${data.roomId}`).emit('message:new', message);
    });

    // Typing indicator (ephemeral — tidak perlu DB)
    socket.on('typing:start', (roomId: string) => {
      socket.to(`room:${roomId}`).emit('typing:update', { userId, roomId, isTyping: true });
    });
    socket.on('typing:stop', (roomId: string) => {
      socket.to(`room:${roomId}`).emit('typing:update', { userId, roomId, isTyping: false });
    });

    // Disconnect
    socket.on('disconnect', async () => {
      await redis.hdel('online_users', userId);
      io.emit('presence:update', { userId, status: 'offline' });
    });
  });

  return io;
}
```

```typescript
// client/hooks/useSocket.ts
import { useEffect, useRef, useCallback } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '@/store/auth';

let socketInstance: Socket | null = null;

export function useSocket() {
  const accessToken = useAuthStore(s => s.accessToken);
  const socketRef = useRef<Socket | null>(null);

  useEffect(() => {
    if (!accessToken) return;
    
    if (!socketInstance) {
      socketInstance = io(process.env.NEXT_PUBLIC_WS_URL!, {
        auth: { token: accessToken },
        transports: ['websocket'],
        reconnection: true,
        reconnectionDelay: 1000,
        reconnectionAttempts: 5,
      });
    }
    
    socketRef.current = socketInstance;

    socketInstance.on('connect', () => console.log('Socket connected'));
    socketInstance.on('disconnect', (reason) => console.log('Socket disconnected:', reason));
    socketInstance.on('connect_error', (err) => console.error('Socket error:', err.message));

    return () => {
      // Don't disconnect on component unmount — shared singleton
    };
  }, [accessToken]);

  const emit = useCallback(<T>(event: string, data: T) => {
    socketRef.current?.emit(event, data);
  }, []);

  const on = useCallback(<T>(event: string, handler: (data: T) => void) => {
    socketRef.current?.on(event, handler);
    return () => socketRef.current?.off(event, handler);
  }, []);

  return { socket: socketRef.current, emit, on };
}
```

---

## 2. SERVER-SENT EVENTS (SSE) IMPLEMENTATION

```typescript
// server: SSE endpoint
app.get('/api/events', auth, (req: Request, res: Response) => {
  const userId = req.user.id;
  
  // SSE headers
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no', // penting untuk Nginx: disable buffering
    'Access-Control-Allow-Origin': process.env.CORS_ORIGIN!,
    'Access-Control-Allow-Credentials': 'true',
  });

  // Send initial ping untuk establish connection
  res.write('event: ping\ndata: connected\n\n');

  // Helper untuk send event
  const sendEvent = (event: string, data: unknown) => {
    res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\nid: ${Date.now()}\n\n`);
  };

  // Subscribe ke Redis pub/sub channel user ini
  const subscriber = redis.duplicate();
  subscriber.subscribe(`sse:${userId}`, (err) => {
    if (err) return res.end();
  });

  subscriber.on('message', (channel, message) => {
    const { event, data } = JSON.parse(message);
    sendEvent(event, data);
  });

  // Heartbeat setiap 30 detik (mencegah proxy timeout)
  const heartbeat = setInterval(() => {
    res.write(': heartbeat\n\n');
  }, 30000);

  // Cleanup saat client disconnect
  req.on('close', () => {
    clearInterval(heartbeat);
    subscriber.unsubscribe();
    subscriber.quit();
  });
});

// Kirim event dari mana saja di backend:
async function pushNotification(userId: string, notification: Notification) {
  await db.notification.create({ data: { userId, ...notification } });
  // Push ke SSE channel user
  await redis.publish(`sse:${userId}`, JSON.stringify({
    event: 'notification:new',
    data: notification,
  }));
}
```

```typescript
// client: EventSource hook
import { useEffect, useRef, useCallback } from 'react';

export function useSSE(url: string, handlers: Record<string, (data: unknown) => void>) {
  const esRef = useRef<EventSource | null>(null);

  useEffect(() => {
    const es = new EventSource(url, { withCredentials: true });
    esRef.current = es;

    es.addEventListener('open', () => console.log('SSE connected'));
    es.addEventListener('error', (e) => {
      console.error('SSE error', e);
      // EventSource auto-reconnects on error — exponential backoff built-in
    });

    // Register custom event handlers
    Object.entries(handlers).forEach(([event, handler]) => {
      es.addEventListener(event, (e: MessageEvent) => handler(JSON.parse(e.data)));
    });

    return () => es.close();
  }, [url]);

  return esRef;
}

// Usage:
useSSE('/api/events', {
  'notification:new': (data) => addNotification(data),
  'message:new': (data) => addMessage(data),
  'presence:update': (data) => updatePresence(data),
});
```

---

## 3. AI RESPONSE STREAMING (ReadableStream)

```typescript
// Next.js route handler untuk AI streaming (OpenAI style)
// app/api/chat/route.ts
import { OpenAI } from 'openai';
import { OpenAIStream, StreamingTextResponse } from 'ai'; // Vercel AI SDK

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export async function POST(req: Request) {
  const { messages } = await req.json();
  
  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages,
    stream: true,
  });

  const stream = OpenAIStream(response, {
    onCompletion: async (completion) => {
      // Save complete message to DB setelah stream selesai
      await db.message.create({ data: { content: completion, role: 'assistant' } });
    },
  });

  return new StreamingTextResponse(stream);
}

// Client: useChat hook dari Vercel AI SDK
import { useChat } from 'ai/react';

export function ChatComponent() {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/chat',
    onFinish: (message) => console.log('Stream complete:', message),
    onError: (error) => console.error('Stream error:', error),
  });

  return (
    <div>
      {messages.map(m => (
        <div key={m.id}>
          <strong>{m.role}:</strong> {m.content}
        </div>
      ))}
      <form onSubmit={handleSubmit}>
        <input value={input} onChange={handleInputChange} />
        <button type="submit" disabled={isLoading}>Send</button>
      </form>
    </div>
  );
}
```

---

## 4. TIPE-TIPE API & KAPAN MASING-MASING

### REST vs GraphQL vs tRPC vs gRPC Decision Matrix

```
REST:
  ✅ Public API (third-party consumers)
  ✅ Simple CRUD
  ✅ Caching di CDN/proxy (GET requests)
  ✅ Team tidak pakai TypeScript
  ❌ Overfetching/underfetching problem
  ❌ N+1 requests untuk nested resources

GraphQL:
  ✅ Complex nested data requirements
  ✅ Multiple clients dengan kebutuhan data berbeda (web, mobile, partner)
  ✅ Rapid prototyping (frontend define query sendiri)
  ✅ Real-time via subscriptions
  ❌ Caching lebih kompleks
  ❌ N+1 problem (butuh DataLoader)
  ❌ Overkill untuk simple CRUD

tRPC:
  ✅ Full-stack TypeScript (Next.js + Node.js)
  ✅ End-to-end type safety tanpa code generation
  ✅ DX terbaik untuk internal API
  ✅ Automatic type inference dari backend ke frontend
  ❌ TypeScript only
  ❌ Tidak untuk public/third-party API

gRPC:
  ✅ Microservices internal communication
  ✅ High performance (binary Protocol Buffers)
  ✅ Streaming (unary, server, client, bidirectional)
  ❌ Tidak browser-native (butuh proxy atau gRPC-Web)
  ❌ Setup lebih kompleks
```

### tRPC Full Setup
```typescript
// server/trpc/router.ts
import { initTRPC, TRPCError } from '@trpc/server';
import { z } from 'zod';

interface Context {
  user: { id: string; role: string } | null;
  db: typeof db;
}

const t = initTRPC.context<Context>().create();

const isAuthed = t.middleware(({ ctx, next }) => {
  if (!ctx.user) throw new TRPCError({ code: 'UNAUTHORIZED' });
  return next({ ctx: { user: ctx.user } });
});

const publicProcedure = t.procedure;
const protectedProcedure = t.procedure.use(isAuthed);

export const appRouter = t.router({
  user: t.router({
    me: protectedProcedure.query(async ({ ctx }) => {
      return ctx.db.user.findUnique({ where: { id: ctx.user.id } });
    }),
    
    updateProfile: protectedProcedure
      .input(z.object({
        name: z.string().min(1).max(100),
        bio: z.string().max(500).optional(),
      }))
      .mutation(async ({ ctx, input }) => {
        return ctx.db.user.update({
          where: { id: ctx.user.id },
          data: input,
        });
      }),
  }),
  
  post: t.router({
    list: publicProcedure
      .input(z.object({
        cursor: z.string().optional(),
        limit: z.number().min(1).max(50).default(20),
      }))
      .query(async ({ ctx, input }) => {
        const posts = await ctx.db.post.findMany({
          take: input.limit + 1,
          cursor: input.cursor ? { id: input.cursor } : undefined,
          orderBy: { createdAt: 'desc' },
        });
        const nextCursor = posts.length > input.limit ? posts.pop()!.id : undefined;
        return { posts, nextCursor };
      }),
      
    create: protectedProcedure
      .input(z.object({ title: z.string().min(1).max(200), content: z.string().min(10) }))
      .mutation(async ({ ctx, input }) => {
        return ctx.db.post.create({ data: { ...input, authorId: ctx.user.id } });
      }),
  }),
});

export type AppRouter = typeof appRouter;

// client/lib/trpc.ts
import { createTRPCReact } from '@trpc/react-query';
import type { AppRouter } from '@/server/trpc/router';

export const trpc = createTRPCReact<AppRouter>();

// Usage di component:
const { data: user } = trpc.user.me.useQuery();
const createPost = trpc.post.create.useMutation({
  onSuccess: () => trpcUtils.post.list.invalidate(),
});
```

---

## 5. API VERSIONING STRATEGIES

```typescript
// Strategy 1: URL versioning (most common, most explicit)
app.use('/api/v1', v1Router);
app.use('/api/v2', v2Router);
// GET /api/v1/users → old behavior
// GET /api/v2/users → new behavior (breaking changes)

// Strategy 2: Header versioning (cleaner URLs, harder to test in browser)
app.use((req, res, next) => {
  const version = req.headers['api-version'] || 'v1';
  req.apiVersion = version;
  next();
});

// Strategy 3: Query param (least recommended, pollutes URLs)
// GET /api/users?version=2

// BEST PRACTICE: URL versioning untuk public API, sembunyikan versi untuk internal API (tRPC/GraphQL handle versioning differently)
```

---

## 6. PAGINATION PATTERNS

### Offset-based Pagination
```typescript
// Simple tapi ada masalah di high-volume data
// GET /api/posts?page=2&limit=20
app.get('/api/posts', async (req, res) => {
  const page = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(100, parseInt(req.query.limit as string) || 20);
  const offset = (page - 1) * limit;
  
  const [posts, total] = await Promise.all([
    db.post.findMany({ skip: offset, take: limit, orderBy: { createdAt: 'desc' } }),
    db.post.count(),
  ]);
  
  return res.json({
    data: posts,
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
      hasNext: page * limit < total,
      hasPrev: page > 1,
    },
  });
});
// ❌ Problem: page 10 bisa berubah isinya jika ada new items di halaman awal
```

### Cursor-based Pagination (keyset) — Recommended untuk feeds
```typescript
// GET /api/posts?cursor=<last_id>&limit=20
// Lebih stabil karena tidak terpengaruh insert/delete
app.get('/api/posts', async (req, res) => {
  const cursor = req.query.cursor as string | undefined;
  const limit = Math.min(50, parseInt(req.query.limit as string) || 20);
  
  const posts = await db.post.findMany({
    take: limit + 1, // fetch 1 extra untuk determine hasNext
    cursor: cursor ? { id: cursor } : undefined,
    orderBy: { createdAt: 'desc' },
    skip: cursor ? 1 : 0, // skip cursor item itself
  });
  
  const hasNext = posts.length > limit;
  if (hasNext) posts.pop(); // remove extra item
  
  const nextCursor = hasNext ? posts[posts.length - 1].id : null;
  
  return res.json({
    data: posts,
    meta: { nextCursor, hasNext, limit },
  });
});
// ✅ Stable untuk infinite scroll / live feeds
// ✅ O(log n) dengan proper index vs O(n) untuk large offsets
```

---

## 7. CACHING STRATEGIES

```typescript
// Cache-aside pattern (most common)
async function getUserById(id: string): Promise<User> {
  const cacheKey = `user:${id}`;
  
  // 1. Check cache
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);
  
  // 2. Cache miss → fetch from DB
  const user = await db.user.findUniqueOrThrow({ where: { id } });
  
  // 3. Store in cache dengan TTL
  await redis.set(cacheKey, JSON.stringify(user), 'EX', 300); // 5 menit
  
  return user;
}

// Invalidate cache setelah update
async function updateUser(id: string, data: UpdateUserDto): Promise<User> {
  const user = await db.user.update({ where: { id }, data });
  await redis.del(`user:${id}`); // invalidate
  return user;
}

// HTTP caching headers
app.get('/api/posts/:id', async (req, res) => {
  const post = await getPostById(req.params.id);
  
  // ETag untuk conditional requests
  const etag = `"${createHash('md5').update(JSON.stringify(post)).digest('hex')}"`;
  
  if (req.headers['if-none-match'] === etag) {
    return res.status(304).end(); // Not Modified — client gunakan cache
  }
  
  res.set({
    'ETag': etag,
    'Cache-Control': 'public, max-age=60, stale-while-revalidate=300',
    'Last-Modified': new Date(post.updatedAt).toUTCString(),
  });
  
  return res.json(post);
});
```

---

## 8. ERROR HANDLING ARCHITECTURE

```typescript
// Custom error classes
export class AppError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public code: string,
    public details?: unknown
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource} with id ${id} not found`, 404, 'NOT_FOUND');
  }
}

export class ValidationError extends AppError {
  constructor(details: unknown) {
    super('Validation failed', 422, 'VALIDATION_ERROR', details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'UNAUTHORIZED');
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Insufficient permissions') {
    super(message, 403, 'FORBIDDEN');
  }
}

// Global error handler middleware (harus 4 args di Express)
export function errorHandler(err: Error, req: Request, res: Response, next: NextFunction) {
  const requestId = req.headers['x-request-id'] as string || randomUUID();
  
  // Log error
  logger.error({
    requestId,
    error: err.message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
    path: req.path,
    method: req.method,
    userId: req.user?.id,
  });
  
  // Report ke Sentry (non-4xx errors)
  if (!(err instanceof AppError) || err.statusCode >= 500) {
    Sentry.captureException(err, { user: req.user ? { id: req.user.id } : undefined });
  }
  
  // Zod validation error
  if (err instanceof ZodError) {
    return res.status(422).json({
      success: false,
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: err.flatten().fieldErrors,
      requestId,
    });
  }
  
  // Custom AppError
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
      code: err.code,
      details: err.details,
      requestId,
    });
  }
  
  // Prisma errors
  if (err.constructor.name === 'PrismaClientKnownRequestError') {
    const prismaErr = err as any;
    if (prismaErr.code === 'P2002') { // Unique constraint
      return res.status(409).json({
        success: false,
        error: 'Resource already exists',
        code: 'CONFLICT',
        requestId,
      });
    }
    if (prismaErr.code === 'P2025') { // Record not found
      return res.status(404).json({
        success: false,
        error: 'Resource not found',
        code: 'NOT_FOUND',
        requestId,
      });
    }
  }
  
  // Generic 500
  return res.status(500).json({
    success: false,
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
    code: 'INTERNAL_ERROR',
    requestId,
  });
}
```

---

## 9. REQUEST LIFECYCLE & MIDDLEWARE ORDER

```typescript
// Express middleware order sangat penting!
import express from 'express';

const app = express();

// 1. Security headers (PERTAMA)
app.use(helmet());

// 2. CORS (sebelum auth)
app.use(cors(corsOptions));

// 3. Request ID (untuk tracing)
app.use((req, res, next) => {
  req.id = req.headers['x-request-id'] as string || randomUUID();
  res.setHeader('X-Request-ID', req.id);
  next();
});

// 4. Logging (setelah request ID)
app.use(requestLogger);

// 5. Body parsing
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// 6. Rate limiting
app.use(globalLimiter);

// 7. Routes
app.use('/api/v1', v1Router);

// 8. 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Route not found', code: 'NOT_FOUND' });
});

// 9. Error handler (TERAKHIR — harus 4 args)
app.use(errorHandler);
```

---

## 10. IDEMPOTENCY UNTUK CRITICAL OPERATIONS

```typescript
// Penting untuk payment, order creation, dll.
// Klien kirim Idempotency-Key header → server store result di Redis

app.post('/api/payments', auth, idempotencyMiddleware, async (req, res) => {
  // Proses payment...
});

function idempotencyMiddleware(req: Request, res: Response, next: NextFunction) {
  const key = req.headers['idempotency-key'] as string;
  if (!key) return next(); // optional untuk non-critical endpoints
  
  const cacheKey = `idempotency:${req.user.id}:${key}`;
  
  (async () => {
    const cached = await redis.get(cacheKey);
    if (cached) {
      const { status, body } = JSON.parse(cached);
      return res.status(status).json(body); // return same response
    }
    
    // Intercept response untuk cache
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      redis.set(cacheKey, JSON.stringify({ status: res.statusCode, body }), 'EX', 86400); // 24 jam
      return originalJson(body);
    };
    
    next();
  })();
}
```

---

*Bxploit Realtime & API Mastery — gas pol, no cap, semua patterns di sini production-grade. 🔥*
