# ⚡ PERFORMANCE OPTIMIZATION & CORE WEB VITALS — Bxploit Knowledge Base
**Version:** 1.0.0 | **Category:** Frontend & Backend Performance Engineering

---

## 1. CORE WEB VITALS — TARGET & CARA UKUR

```
METRIC                    GOOD        NEEDS WORK   POOR
──────────────────────────────────────────────────────────
LCP (Largest Contentful Paint)   < 2.5s      2.5–4s       > 4s
CLS (Cumulative Layout Shift)    < 0.1       0.1–0.25     > 0.25
INP (Interaction to Next Paint)  < 200ms     200–500ms    > 500ms
TTFB (Time to First Byte)        < 800ms     800ms–1.8s   > 1.8s
FCP (First Contentful Paint)     < 1.8s      1.8–3s       > 3s
```

### Cara Ukur
```bash
# Lighthouse CLI
npx lighthouse https://yoursite.com --output=json --view

# Lighthouse CI (di GitHub Actions)
npm install -g @lhci/cli
lhci autorun

# PageSpeed Insights API
curl "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=https://yoursite.com&strategy=mobile"

# Web Vitals di browser (JavaScript)
import { onLCP, onCLS, onINP, onFCP, onTTFB } from 'web-vitals';

onLCP(metric => sendToAnalytics({ name: metric.name, value: metric.value }));
onCLS(metric => sendToAnalytics({ name: metric.name, value: metric.value }));
onINP(metric => sendToAnalytics({ name: metric.name, value: metric.value }));
```

---

## 2. LCP (LARGEST CONTENTFUL PAINT) OPTIMIZATION

### Identify LCP Element
```javascript
// Di DevTools Console:
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log('LCP element:', entry.element);
    console.log('LCP time:', entry.startTime);
  }
}).observe({ type: 'largest-contentful-paint', buffered: true });
```

### Fix LCP
```typescript
// 1. Preload hero image (paling critical)
// app/layout.tsx atau <head>
<link rel="preload" as="image" href="/hero-image.webp" fetchpriority="high" />

// 2. Next.js Image dengan priority
import Image from 'next/image';
<Image
  src="/hero.webp"
  alt="Hero"
  width={1200}
  height={630}
  priority={true}  // ← disable lazy loading, preload otomatis
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>

// 3. Responsive images dengan srcset
<img
  src="/hero-800.webp"
  srcset="/hero-400.webp 400w, /hero-800.webp 800w, /hero-1200.webp 1200w"
  sizes="(max-width: 400px) 400px, (max-width: 800px) 800px, 1200px"
  fetchpriority="high"
  alt="Hero"
/>

// 4. Server-side rendering (SSR/SSG) agar HTML ada konten saat first byte
// Hindari client-side render untuk LCP elements

// 5. Optimasi font loading
import { Inter } from 'next/font/google';
const inter = Inter({
  subsets: ['latin'],
  display: 'swap',    // font-display: swap — prevent invisible text
  preload: true,
  variable: '--font-inter',
});
```

---

## 3. CLS (CUMULATIVE LAYOUT SHIFT) PREVENTION

```css
/* 1. Selalu set width + height pada images */
img {
  width: 100%;
  height: auto;
  aspect-ratio: 16/9; /* prevent reflow */
}

/* 2. Reserve space untuk ads, embeds, iframes */
.ad-container {
  min-height: 250px;
  width: 300px;
}

/* 3. Skeleton loading dengan exact dimensions */
.skeleton {
  width: 100%;
  height: 200px; /* exact height yang akan diisi konten */
  background: linear-gradient(90deg, #1a1a2e 25%, #16213e 50%, #1a1a2e 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

/* 4. Font loading — prevent FOUT shifting layout */
@font-face {
  font-family: 'CustomFont';
  font-display: optional; /* atau 'swap' */
  src: url('/fonts/custom.woff2') format('woff2');
  size-adjust: 100%; /* adjust fallback font size */
}
```

```typescript
// 5. Dynamic content — insert di bawah, bukan di atas viewport
// ❌ SALAH: insert banner di atas konten yang sudah render
document.body.insertBefore(banner, document.body.firstChild); // geser semua konten ke bawah!

// ✅ BENAR: reserve space dari awal
<div style={{ minHeight: '56px' }}> {/* exact height banner */}
  {showBanner && <Banner />}
</div>

// 6. Animasi — gunakan transform, bukan top/left/margin
// ❌ Layout-triggering animations:
.slide { animation: slide-down 0.3s; }
@keyframes slide-down { from { top: -100px; } to { top: 0; } } /* reflow!!! */

// ✅ Composited animations (GPU-accelerated, zero CLS):
.slide { animation: slide-down 0.3s; }
@keyframes slide-down { from { transform: translateY(-100px); } to { transform: translateY(0); } }
```

---

## 4. INP (INTERACTION TO NEXT PAINT) OPTIMIZATION

```typescript
// INP = waktu dari user interaction (click/key) sampai next frame paint
// Target: < 200ms

// 1. useTransition untuk non-urgent updates
import { useTransition, useState } from 'react';

function SearchComponent() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [isPending, startTransition] = useTransition();

  const handleSearch = (value: string) => {
    setQuery(value); // Urgent: update input immediately
    startTransition(() => {
      // Non-urgent: defer expensive filtering
      setResults(filterLargeDataset(value));
    });
  };

  return (
    <>
      <input value={query} onChange={e => handleSearch(e.target.value)} />
      {isPending ? <Spinner /> : <ResultList results={results} />}
    </>
  );
}

// 2. useDeferredValue untuk search/filter
import { useDeferredValue, useMemo } from 'react';

function ProductList({ products, searchQuery }: Props) {
  const deferredQuery = useDeferredValue(searchQuery);
  
  const filtered = useMemo(
    () => products.filter(p => p.name.includes(deferredQuery)),
    [products, deferredQuery]
  );
  
  return <div className={searchQuery !== deferredQuery ? 'opacity-50' : ''}>{/* ... */}</div>;
}

// 3. Virtualize long lists (paling impactful untuk INP)
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);
  
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 80, // estimated item height
    overscan: 5, // render 5 items di luar viewport
  });

  return (
    <div ref={parentRef} style={{ height: '600px', overflow: 'auto' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <Item item={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}

// 4. Debounce event handlers
import { useCallback } from 'react';
import { useDebouncedCallback } from 'use-debounce';

const handleSearch = useDebouncedCallback((value: string) => {
  fetchSearchResults(value);
}, 300);
```

---

## 5. BUNDLE SIZE OPTIMIZATION

```typescript
// 1. Bundle analysis
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});
// Run: ANALYZE=true npm run build

// 2. Dynamic imports untuk heavy components
import dynamic from 'next/dynamic';

// Komponene yang besar/jarang dipakai
const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <ChartSkeleton />,
  ssr: false, // disable SSR jika tidak diperlukan (charts, maps)
});

const ReactQuill = dynamic(() => import('react-quill'), {
  ssr: false,
  loading: () => <div className="h-64 bg-slate-800 animate-pulse rounded-lg" />,
});

// 3. Tree shaking — import spesifik, bukan whole library
// ❌ SALAH:
import _ from 'lodash'; // bundle seluruh lodash (~70KB)
const result = _.cloneDeep(obj);

// ✅ BENAR:
import cloneDeep from 'lodash/cloneDeep'; // hanya modul yang dipakai (~5KB)
// atau pakai native: structuredClone(obj) (ES2022)

// ❌ SALAH:
import { motion, AnimatePresence, useScroll } from 'framer-motion'; // fine karena modular

// ✅ Date library — pakai date-fns (tree-shakeable) vs moment.js (monolithic)
import { format, addDays, differenceInDays } from 'date-fns'; // hanya fungsi yang dipakai

// 4. Next.js automatic code splitting
// Setiap page.tsx otomatis jadi separate bundle
// Layout.tsx shared di dalam route group

// 5. Lazy load images below the fold
<Image src="/below-fold.webp" alt="..." loading="lazy" /> // default di Next.js Image

// 6. Preconnect ke external domains
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://api.yoursite.com" />
<link rel="dns-prefetch" href="https://cdn.yoursite.com" />
```

---

## 6. NEXT.JS CACHING LAYERS (PENTING BANGET)

```typescript
// Next.js App Router punya 4 cache layers:

// 1. Request Memoization (per-request, dalam 1 render)
// fetch() yang sama URL + options di-deduplicate otomatis dalam 1 SSR render
async function getUser(id: string) {
  const res = await fetch(`https://api/users/${id}`); // ← dipanggil berkali-kali
  return res.json(); // ← hanya 1 actual network request!
}

// 2. Data Cache (persistent, cross-request)
// default: cached forever sampai revalidate/invalidate
const res = await fetch('https://api/products', {
  next: { revalidate: 3600 }, // ISR: revalidate setiap 1 jam
});

// Opt-out caching:
const res = await fetch('https://api/realtime-data', {
  cache: 'no-store', // selalu fresh dari server
});

// 3. Full Route Cache (static HTML + RSC payload, server-side)
// Pages yang tidak ada dynamic data di-cache sebagai static HTML
// Revalidate dengan: revalidatePath() atau revalidateTag()

// 4. Router Cache (client-side, browser)
// Prefetch & cache RSC payload di browser saat navigate
// Duration: 30s untuk static, 5s untuk dynamic

// ─────────── REVALIDATION ───────────

// Tag-based revalidation (paling fleksibel)
// Saat fetch:
const posts = await fetch('https://api/posts', {
  next: { tags: ['posts'] },
});

// Saat ada update (di server action atau route handler):
import { revalidateTag } from 'next/cache';
await db.post.create({ data: newPost });
revalidateTag('posts'); // invalidate semua fetch yang pakai tag 'posts'

// Path-based revalidation:
import { revalidatePath } from 'next/cache';
revalidatePath('/blog'); // invalidate route /blog
revalidatePath('/blog/[slug]', 'page'); // invalidate semua dynamic blog pages

// On-demand ISR dari API route:
export async function POST(req: Request) {
  const { secret, path } = await req.json();
  if (secret !== process.env.REVALIDATION_SECRET) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }
  revalidatePath(path);
  return Response.json({ revalidated: true });
}
```

---

## 7. IMAGE OPTIMIZATION

```typescript
// Format hierarchy (terkecil ke terbesar):
// AVIF > WebP > PNG/JPEG
// AVIF: ~50% lebih kecil dari WebP, ~80% dari JPEG
// WebP: ~30% lebih kecil dari JPEG

// Next.js Image auto-convert ke WebP/AVIF + lazy load + correct sizing
import Image from 'next/image';

<Image
  src="/product.jpg"      // source bisa JPEG/PNG
  alt="Product"
  width={800}             // intrinsic width
  height={600}            // intrinsic height
  quality={85}            // 85 balance quality vs size (default 75)
  placeholder="blur"      // blur-up effect saat loading
  blurDataURL={blurDataUrl} // low-res base64 placeholder
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
  // ↑ Critical untuk responsive! Tanpa ini, browser download ukuran penuh
  className="object-cover"
/>

// Generate blur placeholder dengan plaiceholder:
import { getPlaiceholder } from 'plaiceholder';
const { base64 } = await getPlaiceholder('/public/image.jpg');
// base64 = tiny blur placeholder untuk blurDataURL

// SVG optimization — gunakan SVGO
npx svgo input.svg -o output.svg

// Sharp untuk server-side image processing
import sharp from 'sharp';
async function processUploadedImage(buffer: Buffer): Promise<{ webp: Buffer; thumbnail: Buffer }> {
  const [webp, thumbnail] = await Promise.all([
    sharp(buffer)
      .resize(1200, 630, { fit: 'cover', position: 'center' })
      .webp({ quality: 85 })
      .toBuffer(),
    sharp(buffer)
      .resize(400, 300, { fit: 'cover' })
      .webp({ quality: 70 })
      .toBuffer(),
  ]);
  return { webp, thumbnail };
}
```

---

## 8. BACKEND PERFORMANCE

```typescript
// 1. Database query optimization — paling impactful
// N+1 problem dengan Prisma:
// ❌ N+1: 1 query untuk posts + N queries untuk setiap author
const posts = await db.post.findMany();
for (const post of posts) {
  post.author = await db.user.findUnique({ where: { id: post.authorId } }); // N queries!
}

// ✅ Eager loading dengan include:
const posts = await db.post.findMany({
  include: {
    author: { select: { id: true, name: true, avatarUrl: true } }, // 1 JOIN query
    _count: { select: { comments: true, likes: true } },
  },
});

// ✅ Select hanya field yang dibutuhkan:
const users = await db.user.findMany({
  select: { id: true, name: true, email: true }, // bukan select *
});

// 2. Connection pooling
// Prisma Accelerate atau PgBouncer untuk production
// DATABASE_URL="postgresql://...?pgbouncer=true&connection_limit=1"

// Drizzle dengan pg pool:
import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,          // max connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
export const db = drizzle(pool);

// 3. Redis caching untuk expensive queries
async function getTopProducts(categoryId: string): Promise<Product[]> {
  const cacheKey = `top_products:${categoryId}`;
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);
  
  const products = await db.product.findMany({
    where: { categoryId, isActive: true },
    orderBy: [{ soldCount: 'desc' }, { rating: 'desc' }],
    take: 20,
    include: { images: { take: 1 } },
  });
  
  await redis.set(cacheKey, JSON.stringify(products), 'EX', 600); // 10 menit
  return products;
}

// 4. Response compression
import compression from 'compression';
app.use(compression({
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  },
  threshold: 1024, // compress jika > 1KB
}));

// 5. HTTP/2 Server Push (via Nginx/CDN) untuk critical assets
// Di Next.js: gunakan Link preload di <head>
<link rel="preload" as="script" href="/_next/static/chunks/main.js" />

// 6. Streaming responses (Next.js App Router)
// Suspense boundaries untuk streaming HTML
export default function Page() {
  return (
    <div>
      <StaticHeader />           {/* sent immediately */}
      <Suspense fallback={<Skeleton />}>
        <AsyncDataComponent />   {/* streamed saat data ready */}
      </Suspense>
      <StaticFooter />           {/* sent immediately */}
    </div>
  );
}
```

---

## 9. PERFORMANCE MONITORING & ALERTING

```typescript
// Vercel Analytics (paling mudah untuk Next.js)
// app/layout.tsx
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
        <SpeedInsights />  {/* Real Core Web Vitals dari real users */}
      </body>
    </html>
  );
}

// Custom performance marks
performance.mark('component-render-start');
// ... render
performance.mark('component-render-end');
performance.measure('component-render', 'component-render-start', 'component-render-end');
const [measure] = performance.getEntriesByName('component-render');
console.log(`Render took: ${measure.duration}ms`);

// Lighthouse CI config (lighthouserc.js)
module.exports = {
  ci: {
    collect: {
      url: ['http://localhost:3000', 'http://localhost:3000/pricing'],
      numberOfRuns: 3,
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],      // > 90
        'categories:accessibility': ['error', { minScore: 0.95 }],   // > 95
        'categories:best-practices': ['warn', { minScore: 0.9 }],
        'categories:seo': ['warn', { minScore: 0.9 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
      },
    },
    upload: {
      target: 'lhci', // atau 'temporary-public-storage'
      serverBaseUrl: process.env.LHCI_SERVER_URL,
      token: process.env.LHCI_TOKEN,
    },
  },
};
```

---

## 10. PERFORMANCE CHECKLIST PRE-LAUNCH

### Images
- [ ] Semua images pakai Next.js `<Image>` component
- [ ] Hero image punya `priority={true}`
- [ ] `sizes` prop diset dengan benar untuk responsive images
- [ ] Format WebP/AVIF digunakan (Next.js auto-convert)
- [ ] Below-fold images gunakan lazy loading (default)

### JavaScript
- [ ] Bundle analyzer dijalankan, tidak ada obvious bloat
- [ ] Heavy components (chart, editor, map) pakai dynamic import
- [ ] Lodash/moment diganti dengan tree-shakeable alternatives
- [ ] Third-party scripts (analytics, chat) loaded async/defer

### CSS & Fonts
- [ ] Font `display: swap` atau `display: optional`
- [ ] Critical CSS inlined (Next.js otomatis)
- [ ] Tidak ada CLS dari font loading (size-adjust)
- [ ] CSS animations pakai `transform`/`opacity`, bukan `top`/`left`

### Caching & Network
- [ ] Static assets punya long-lived cache headers (`immutable`)
- [ ] API responses punya appropriate cache headers
- [ ] CDN terkonfigurasi untuk static assets
- [ ] `revalidate` strategy clear untuk setiap data fetch

### Backend
- [ ] Database indexes ada di semua FK + filter + sort columns
- [ ] N+1 queries sudah dieliminasi
- [ ] Connection pooling aktif
- [ ] Response compression (gzip/brotli) aktif

---

*Bxploit Performance Mastery — Speed is a feature. No cap. ⚡🔥*
