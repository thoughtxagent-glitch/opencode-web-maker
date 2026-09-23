# ⚛️ SKILL: Frontend Modern Mastery (Next.js, React 19, Tailwind CSS v4)

## Architecture & Framework Rules
- Next.js 14/15 App Router: Strict Server Components (`RSC`) by default. Use `"use client"` only for interactive leaves.
- Server Actions & Mutation: Type-safe mutation handlers paired with `useActionState` and `useOptimistic`.
- State Management: Zustand for global UI state, TanStack React Query v5 for server state caching & revalidation.
- Styling: Tailwind CSS v4 `@theme` directive, CSS Variables, Radix UI Primitives, Shadcn/ui components.

## Performance & Optimization
- Images: `next/image` with explicit `sizes`, `priority` on LCP elements, WebP/AVIF format.
- Code Splitting: `next/dynamic` for heavy client components (charts, WebGL, rich text editors).
- Fonts: `next/font` with `display: 'swap'` and preloaded subset.
