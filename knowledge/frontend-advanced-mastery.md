# ⚛️ ADVANCED FRONTEND & STATE MANAGEMENT — Bxploit Knowledge Base
**Version:** 1.0.0 | **Category:** Advanced Frontend Engineering

---

## 1. REACT 18/19 INTERNALS & CONCURRENT FEATURES

### Fiber Architecture & Reconciliation
React Fiber membagi rendering work menjadi unit-unit kecil (fibers) yang bisa di-pause, abort, atau re-use berdasarkan prioritas (time-slicing).
- **Render Phase** (Async, reconciler): Menyusun Fiber tree, diffing DOM virtual. Bisa di-interrupt.
- **Commit Phase** (Sync, renderer): Mengaplikasikan perubahan ke real DOM. Tidak bisa di-interrupt.

### Concurrent Features
```typescript
// 1. useTransition — pisahkan urgent vs non-urgent state updates
import { useState, useTransition } from 'react';

export function TabContainer() {
  const [isPending, startTransition] = useTransition();
  const [tab, setTab] = useState('about');

  function selectTab(nextTab: string) {
    // Non-urgent: biarkan UI tetap responsif saat render tab berat
    startTransition(() => {
      setTab(nextTab);
    });
  }

  return (
    <div>
      <TabButton isActive={tab === 'about'} onClick={() => selectTab('about')}>About</TabButton>
      <TabButton isActive={tab === 'posts'} onClick={() => selectTab('posts')}>Posts (Heavy)</TabButton>
      {isPending && <Spinner />}
      {tab === 'about' && <AboutTab />}
      {tab === 'posts' && <PostsTab />}
    </div>
  );
}

// 2. useDeferredValue — defer re-rendering nilai yang berubah cepat
import { useState, useDeferredValue } from 'react';

export function SearchPage() {
  const [query, setQuery] = useState('');
  const deferredQuery = useDeferredValue(query); // Defer query untuk list render

  return (
    <div>
      <input value={query} onChange={e => setQuery(e.target.value)} />
      {/* Input di-update instant, List di-update saat CPU idle */}
      <HeavyList query={deferredQuery} />
    </div>
  );
}
```

---

## 2. NEXT.JS APP ROUTER MASTER PATTERNS

### React Server Components (RSC) vs Client Components
- **RSC (default)**: Executed ONLY di server. Bundled size 0kb ke browser. Akses DB & file system langsung.
- **Client Components (`'use client'`)**: Executed di server (SSR) & hydrated di client. Diperlukan untuk interactivity, hooks (`useState`, `useEffect`), event listeners.

```typescript
// app/dashboard/page.tsx (Server Component)
import { db } from '@/lib/db';
import { UserProfile } from './user-profile'; // Client Component

export default async function DashboardPage() {
  // Fetch data langsung di server — zero API endpoint needed!
  const users = await db.user.findMany({ take: 10 });

  return (
    <main className="p-8">
      <h1 className="text-2xl font-bold">Dashboard</h1>
      {/* Pass server data ke client component */}
      <UserProfile initialUsers={users} />
    </main>
  );
}
```

### Server Actions (Form & Data Mutations)
```typescript
// app/actions/user.ts
'use server';

import { z } from 'zod';
import { db } from '@/lib/db';
import { revalidatePath } from 'next/cache';

const updateUserSchema = z.object({
  id: z.string(),
  name: z.string().min(2),
});

export async function updateUserNameAction(prevState: any, formData: FormData) {
  const rawData = {
    id: formData.get('id') as string,
    name: formData.get('name') as string,
  };

  const validated = updateUserSchema.safeParse(rawData);
  if (!validated.success) {
    return { error: 'Validation failed', fields: validated.error.flatten().fieldErrors };
  }

  try {
    await db.user.update({
      where: { id: validated.data.id },
      data: { name: validated.data.name },
    });

    revalidatePath('/dashboard'); // Auto-refresh server component cache
    return { success: true, error: null };
  } catch (e) {
    return { error: 'Failed to update database', fields: null };
  }
}
```

---

## 3. STATE MANAGEMENT ARCHITECTURE

### Zustand (Client Global State)
```typescript
// store/use-cart-store.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';

interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  clearCart: () => void;
  totalPrice: () => number;
}

export const useCartStore = create<CartStore>()(
  persist(
    (set, get) => ({
      items: [],
      addItem: (newItem) => set((state) => {
        const existing = state.items.find(i => i.id === newItem.id);
        if (existing) {
          return {
            items: state.items.map(i => 
              i.id === newItem.id ? { ...i, quantity: i.quantity + newItem.quantity } : i
            )
          };
        }
        return { items: [...state.items, newItem] };
      }),
      removeItem: (id) => set((state) => ({
        items: state.items.filter(i => i.id !== id)
      })),
      clearCart: () => set({ items: [] }),
      totalPrice: () => get().items.reduce((sum, i) => sum + (i.price * i.quantity), 0),
    }),
    {
      name: 'cart-storage',
      storage: createJSONStorage(() => localStorage),
    }
  )
);
```

### TanStack Query v5 (Server State & Caching)
```typescript
// hooks/use-users-query.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

async function fetchUsers() {
  const res = await fetch('/api/users');
  if (!res.ok) throw new Error('Network response was not ok');
  return res.json();
}

export function useUsers() {
  return useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
    staleTime: 1000 * 60 * 5, // 5 menit dianggap fresh (tanpa background refetch)
    gcTime: 1000 * 60 * 30,    // 30 menit simpan di memory cache
  });
}

// Optimistic Update Pattern
export function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (updatedUser: { id: string; name: string }) => {
      const res = await fetch(`/api/users/${updatedUser.id}`, {
        method: 'PATCH',
        body: JSON.stringify(updatedUser),
      });
      return res.json();
    },
    onMutate: async (newUser) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['users'] });
      // Snapshot previous value
      const previousUsers = queryClient.getQueryData(['users']);
      // Optimistically update to the new value
      queryClient.setQueryData(['users'], (old: any) => 
        old?.map((u: any) => u.id === newUser.id ? { ...u, ...newUser } : u)
      );
      return { previousUsers };
    },
    onError: (err, newUser, context) => {
      // Rollback ke value sebelumnya jika gagal
      queryClient.setQueryData(['users'], context?.previousUsers);
    },
    onSettled: () => {
      // Sync ulang dengan server
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}
```

---

## 4. FRAMER MOTION & KINETIC ANIMATIONS

```typescript
// components/bento-card.tsx
'use client';

import { motion } from 'framer-motion';

export function BentoCard({ title, description }: { title: string; description: string }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }} // Spring physics curve
      whileHover={{ scale: 1.02, translateY: -4 }}
      whileTap={{ scale: 0.98 }}
      className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-xl shadow-xl hover:border-cyan-500/50 transition-colors"
    >
      <h3 className="text-xl font-bold text-white mb-2">{title}</h3>
      <p className="text-slate-400 text-sm">{description}</p>
    </motion.div>
  );
}
```

---

*Bxploit Advanced Frontend Mastery — Fully Documented & Production Grade.*
