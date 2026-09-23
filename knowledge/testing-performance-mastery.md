# Testing & Performance Engineering Mastery
> Bxploit Knowledge Base — Testing, QA & Performance untuk Fullstack Website
> Level: Senior Engineer | Gaya: Sigma, no bullshit, battle-tested

---

## 1. TESTING PHILOSOPHY & STRATEGY

### Testing Pyramid vs Testing Trophy

**Testing Pyramid (klasik, Mike Cohn)**:
```
        /\
       /E2E\        ← 10% — expensive, slow, brittle
      /------\
     /  Integ  \    ← 20% — medium cost, real deps
    /------------\
   /   Unit Tests  \ ← 70% — cheap, fast, isolated
  /------------------\
```

Pyramid cocok buat:
- Apps dengan banyak pure business logic (kalkulasi, transformasi data)
- Library/package yang harus super reliable
- Team besar dengan dedicated QA

**Testing Trophy (Kent C. Dodds) — lebih relevan untuk modern web**:
```
        [ E2E ]         ← sedikit tapi crucial user journeys
     [ Integration ]    ← CORE — ini yang paling valuable
   [  Unit  |  Unit  ]  ← untuk isolated logic, utils, helpers
        [ Static ]      ← TypeScript, ESLint — free checks
```

Trophy insight: Integration tests memberikan **confidence tertinggi per effort**. Unit tests yang testing implementation details (bukan behavior) itu waste. E2E terlalu slow untuk jadi coverage backbone.

**Rule of thumb**:
- Unit → pure functions, complex algorithms, isolated business logic
- Integration → API routes, DB queries, component + hooks combined
- E2E → critical user paths: login, checkout, onboarding

---

### TDD: Red-Green-Refactor

```
RED → tulis test yang fail dulu
GREEN → tulis minimum code biar test pass
REFACTOR → clean up, tanpa ngubah behavior
```

TDD mindset yang bener:
```typescript
// Step 1: RED — test fail
describe('calculateDiscount', () => {
  it('applies 10% discount for orders above 100k', () => {
    expect(calculateDiscount(150000, 'MEMBER')).toBe(135000)
  })
})
// ReferenceError: calculateDiscount is not defined ✓ (expected fail)

// Step 2: GREEN — minimal implementation
function calculateDiscount(amount: number, type: string): number {
  if (type === 'MEMBER' && amount > 100000) {
    return amount * 0.9
  }
  return amount
}

// Step 3: REFACTOR
const DISCOUNT_RULES = {
  MEMBER: { threshold: 100000, rate: 0.1 },
  VIP: { threshold: 50000, rate: 0.15 },
} as const

function calculateDiscount(amount: number, type: keyof typeof DISCOUNT_RULES): number {
  const rule = DISCOUNT_RULES[type]
  if (!rule || amount <= rule.threshold) return amount
  return amount * (1 - rule.rate)
}
```

TDD bukan silver bullet — overkill untuk:
- Exploratory code / prototypes
- UI/visual components
- Database migrations

Tepat untuk: business logic, algorithms, API contracts.

---

### BDD: Behavior-Driven Development

Gherkin syntax — nulis test dalam bahasa domain:
```gherkin
# features/checkout.feature
Feature: Checkout Process
  Background:
    Given user sudah login sebagai "member@test.com"
    And ada 2 items di cart

  Scenario: Successful checkout dengan kartu kredit
    When user clicks "Proceed to Checkout"
    And user fills payment info dengan valid card
    And user clicks "Place Order"
    Then user melihat order confirmation page
    And order status adalah "PENDING"
    And user menerima email konfirmasi

  Scenario: Checkout gagal karena kartu expired
    When user clicks "Proceed to Checkout"
    And user fills payment info dengan expired card
    And user clicks "Place Order"
    Then user melihat error "Card has expired"
    And order tidak di-create
```

Step definitions (dengan Cucumber.js + Playwright):
```typescript
import { Given, When, Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'

Given('user sudah login sebagai {string}', async function(email: string) {
  await this.page.goto('/login')
  await this.page.getByLabel('Email').fill(email)
  await this.page.getByLabel('Password').fill('password123')
  await this.page.getByRole('button', { name: 'Login' }).click()
  await this.page.waitForURL('/dashboard')
})

When('user clicks {string}', async function(buttonText: string) {
  await this.page.getByRole('button', { name: buttonText }).click()
})

Then('user melihat order confirmation page', async function() {
  await expect(this.page.getByRole('heading', { name: /Order Confirmed/i })).toBeVisible()
})
```

---

### Property-Based Testing dengan fast-check

Property-based testing: generate hundreds of random inputs, cari edge cases yang lo gak kepikiran.

```typescript
import fc from 'fast-check'

describe('sanitizeHtml', () => {
  // Biasa: test specific cases
  it('removes script tags', () => {
    expect(sanitizeHtml('<script>alert(1)</script>hello')).toBe('hello')
  })

  // Property-based: test invariants untuk SEMUA inputs
  it('never produces output longer than input', () => {
    fc.assert(
      fc.property(fc.string(), (input) => {
        const output = sanitizeHtml(input)
        return output.length <= input.length
      })
    )
  })

  it('output tidak mengandung script tags untuk any input', () => {
    fc.assert(
      fc.property(fc.string(), (input) => {
        const output = sanitizeHtml(input)
        return !output.includes('<script') && !output.includes('</script>')
      })
    )
  })

  it('idempotent — sanitize dua kali sama dengan sekali', () => {
    fc.assert(
      fc.property(fc.string(), (input) => {
        return sanitizeHtml(sanitizeHtml(input)) === sanitizeHtml(input)
      })
    )
  })
})

// Custom arbitraries untuk domain-specific types
const validEmail = fc.emailAddress()
const validPrice = fc.float({ min: 0, max: 999999, noNaN: true })
const userId = fc.uuid()

describe('order pricing', () => {
  it('total selalu >= subtotal (discount gak bikin harga negatif)', () => {
    fc.assert(
      fc.property(validPrice, fc.integer({ min: 1, max: 100 }), (price, qty) => {
        const order = createOrder(price, qty)
        return order.total >= 0 && order.total <= order.subtotal
      })
    )
  })
})
```

---

## 2. UNIT TESTING DENGAN JEST

### Jest Configuration — `jest.config.ts`

```typescript
// jest.config.ts
import type { Config } from 'jest'

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node', // 'jsdom' untuk React components

  // Transform
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {
      tsconfig: { strict: true }
    }]
  },

  // Module resolution (sesuaikan dengan tsconfig paths)
  moduleNameMapper: {
    '^#/(.*)$': '<rootDir>/src/$1',
    '^@/(.*)$': '<rootDir>/src/$1',
    '\\.css$': '<rootDir>/__mocks__/styleMock.js',
    '\\.(jpg|jpeg|png|svg)$': '<rootDir>/__mocks__/fileMock.js',
  },

  // Setup files
  setupFilesAfterFramework: ['<rootDir>/jest.setup.ts'],

  // Coverage
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.tsx',
    '!src/**/index.ts', // barrel files — no logic
  ],
  coverageThresholds: {
    global: {
      statements: 80,
      branches: 75,
      functions: 80,
      lines: 80,
    },
    // Per-directory thresholds untuk business logic
    './src/lib/': {
      branches: 90,
      functions: 95,
    }
  },

  // Performance
  maxWorkers: '50%',
  testTimeout: 10000,
}

export default config
```

```typescript
// jest.setup.ts
import '@testing-library/jest-dom'
import { server } from './src/mocks/server' // MSW

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

---

### Test Structure & Matchers

```typescript
describe('UserService', () => {
  let userService: UserService
  let mockDb: jest.Mocked<Database>

  beforeAll(() => {
    // Run once — expensive setup
    mockDb = createMockDb()
  })

  beforeEach(() => {
    // Run per test — reset state
    userService = new UserService(mockDb)
    jest.clearAllMocks()
  })

  afterEach(() => {
    // Cleanup
  })

  afterAll(() => {
    // Teardown expensive resources
    mockDb.close()
  })

  describe('createUser', () => {
    it('creates user dengan valid data', async () => {
      const userData = { email: 'test@test.com', name: 'Test User' }
      mockDb.users.insert.mockResolvedValue({ id: '123', ...userData })

      const result = await userService.createUser(userData)

      // toEqual: deep equality (ignores undefined props)
      expect(result).toEqual({ id: '123', email: 'test@test.com', name: 'Test User' })

      // toStrictEqual: strict — includes undefined properties
      expect(result).toStrictEqual({ id: '123', email: 'test@test.com', name: 'Test User' })

      // toMatchObject: subset matching — result bisa punya extra props
      expect(result).toMatchObject({ email: 'test@test.com' })

      // Verify mock calls
      expect(mockDb.users.insert).toHaveBeenCalledTimes(1)
      expect(mockDb.users.insert).toHaveBeenCalledWith(
        expect.objectContaining({ email: 'test@test.com' })
      )
    })

    it('throws ValidationError untuk invalid email', async () => {
      await expect(
        userService.createUser({ email: 'not-an-email', name: 'Test' })
      ).rejects.toThrow(ValidationError)

      await expect(
        userService.createUser({ email: 'not-an-email', name: 'Test' })
      ).rejects.toThrow('Invalid email format')
    })

    it('matches snapshot untuk response shape', async () => {
      mockDb.users.insert.mockResolvedValue({ id: '123', email: 'a@b.com', name: 'A' })
      const result = await userService.createUser({ email: 'a@b.com', name: 'A' })

      // Inline snapshot — tersimpan langsung di test file
      expect(result).toMatchInlineSnapshot(`
        {
          "email": "a@b.com",
          "id": "123",
          "name": "A",
        }
      `)
    })
  })
})
```

---

### Mocking Strategies

```typescript
// 1. jest.fn() — basic mock function
const mockFn = jest.fn()
mockFn.mockReturnValue(42)
mockFn.mockReturnValueOnce('first call').mockReturnValueOnce('second call')
mockFn.mockResolvedValue({ data: 'async result' }) // untuk async
mockFn.mockRejectedValue(new Error('async error'))
mockFn.mockImplementation((x: number) => x * 2)

// 2. jest.spyOn() — spy tanpa replace, atau replace implementation
const spy = jest.spyOn(console, 'error').mockImplementation(() => {})
const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue(
  new Response(JSON.stringify({ data: 'ok' }))
)
// Setelah test:
spy.mockRestore() // restore original implementation

// 3. jest.mock() — module-level mock
jest.mock('../lib/database', () => ({
  db: {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
    }
  }
}))

// Untuk mock dengan partial retain:
jest.mock('../lib/email', () => ({
  ...jest.requireActual('../lib/email'), // keep real implementations
  sendEmail: jest.fn().mockResolvedValue({ messageId: 'mock-123' })
}))

// 4. Fake Timers
describe('debounce', () => {
  beforeEach(() => jest.useFakeTimers())
  afterEach(() => jest.useRealTimers())

  it('delays execution', () => {
    const fn = jest.fn()
    const debounced = debounce(fn, 500)

    debounced()
    expect(fn).not.toHaveBeenCalled()

    jest.advanceTimersByTime(499)
    expect(fn).not.toHaveBeenCalled()

    jest.advanceTimersByTime(1)
    expect(fn).toHaveBeenCalledTimes(1)
  })

  it('handles Date.now()', () => {
    jest.setSystemTime(new Date('2025-01-01T00:00:00Z'))
    expect(new Date().getFullYear()).toBe(2025)
  })
})
```

```typescript
// __mocks__/nodemailer.ts — Manual mock
const mockSendMail = jest.fn().mockResolvedValue({ messageId: 'test-message-id' })

const mockTransporter = {
  sendMail: mockSendMail,
  verify: jest.fn().mockResolvedValue(true),
}

export const createTransport = jest.fn().mockReturnValue(mockTransporter)
export { mockSendMail } // Export untuk assertions di tests
```

---

### Vitest — Alternatif Modern Jest

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import path from 'path'

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true, // describe, it, expect tanpa import
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov', 'html'],
      thresholds: { lines: 80, branches: 75 },
    },
    // Concurrent tests per file
    pool: 'forks',
    poolOptions: {
      forks: { singleFork: false }
    }
  },
  resolve: {
    alias: { '#': path.resolve(__dirname, './src') }
  }
})
```

Vitest wins:
- **10-20x faster** startup (no babel transform needed, native ESM)
- Same API sebagai Jest — migration minimal
- `vi.fn()`, `vi.spyOn()`, `vi.mock()` — drop-in replacements
- Hot Module Replacement dalam watch mode
- Built-in TypeScript support tanpa ts-jest

---

## 3. REACT TESTING LIBRARY

### Philosophy & Query Priority

RTL mantra: **"The more your tests resemble the way your software is used, the more confidence they can give you."**

Jangan test internal state, test user behavior.

Query priority (dari paling direkomendasikan):
```typescript
// 1. getByRole — best: accessible, semantic
screen.getByRole('button', { name: /submit/i })
screen.getByRole('textbox', { name: /email/i })
screen.getByRole('heading', { level: 1 })
screen.getByRole('checkbox', { name: /remember me/i })
screen.getByRole('combobox', { name: /country/i }) // select

// 2. getByLabelText — forms
screen.getByLabelText('Email address')
screen.getByLabelText(/password/i)

// 3. getByPlaceholderText — kalau gak ada label
screen.getByPlaceholderText('Search...')

// 4. getByText — untuk non-interactive content
screen.getByText(/welcome back/i)
screen.getByText('Submit', { exact: false })

// 5. getByTestId — last resort
screen.getByTestId('user-avatar')
// Set di component: <div data-testid="user-avatar">

// HINDARI: getByClassName, container.querySelector — ini test implementation
```

---

### Testing Components — Full Example

```typescript
// LoginForm.test.tsx
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { LoginForm } from './LoginForm'
import { server } from '../mocks/server'
import { http, HttpResponse } from 'msw'

describe('LoginForm', () => {
  const user = userEvent.setup()

  it('shows validation errors ketika submit kosong', async () => {
    render(<LoginForm />)

    await user.click(screen.getByRole('button', { name: /login/i }))

    expect(await screen.findByText(/email is required/i)).toBeInTheDocument()
    expect(await screen.findByText(/password is required/i)).toBeInTheDocument()
  })

  it('calls onSuccess setelah login berhasil', async () => {
    const onSuccess = jest.fn()
    render(<LoginForm onSuccess={onSuccess} />)

    await user.type(screen.getByLabelText(/email/i), 'test@test.com')
    await user.type(screen.getByLabelText(/password/i), 'password123')
    await user.click(screen.getByRole('button', { name: /login/i }))

    // Wait for async operation
    await waitFor(() => {
      expect(onSuccess).toHaveBeenCalledWith(
        expect.objectContaining({ email: 'test@test.com' })
      )
    })
  })

  it('shows error message ketika credentials invalid', async () => {
    // Override MSW handler untuk test ini
    server.use(
      http.post('/api/auth/login', () => {
        return HttpResponse.json(
          { error: 'Invalid credentials' },
          { status: 401 }
        )
      })
    )

    render(<LoginForm />)
    await user.type(screen.getByLabelText(/email/i), 'wrong@test.com')
    await user.type(screen.getByLabelText(/password/i), 'wrongpass')
    await user.click(screen.getByRole('button', { name: /login/i }))

    expect(await screen.findByRole('alert')).toHaveTextContent(/invalid credentials/i)
  })

  it('disables button saat loading', async () => {
    render(<LoginForm />)
    await user.type(screen.getByLabelText(/email/i), 'test@test.com')
    await user.type(screen.getByLabelText(/password/i), 'password123')
    await user.click(screen.getByRole('button', { name: /login/i }))

    // Immediately after click, button should be disabled
    expect(screen.getByRole('button', { name: /loading/i })).toBeDisabled()
  })
})
```

---

### `userEvent` vs `fireEvent`

```typescript
// fireEvent — langsung fire DOM event, tidak simulate user behavior
fireEvent.change(input, { target: { value: 'hello' } })
fireEvent.click(button)
// Problem: tidak trigger focus, blur, keyboard events yang real user lakukan

// userEvent v14 — simulate actual user behavior, PREFERRED
const user = userEvent.setup()
await user.type(input, 'hello') // triggers focus, keydown, keypress, keyup, input, change
await user.click(button)        // triggers pointerover, pointerenter, mouseover, mouseenter, pointermove, mousemove, pointerdown, mousedown, focus, pointerup, mouseup, click
await user.tab()                // keyboard navigation
await user.keyboard('{Enter}')  // special keys
await user.selectOptions(select, ['option-value'])
await user.upload(fileInput, new File(['content'], 'test.png', { type: 'image/png' }))
await user.paste('pasted text')

// Kapan masih pakai fireEvent:
// - Testing edge cases low-level events
// - Perlu control granular atas event properties
// - Performance test dengan volume banyak
```

---

### Testing Custom Hooks

```typescript
// useCounter.test.ts
import { renderHook, act } from '@testing-library/react'
import { useCounter } from './useCounter'

describe('useCounter', () => {
  it('initializes dengan default value', () => {
    const { result } = renderHook(() => useCounter())
    expect(result.current.count).toBe(0)
  })

  it('initializes dengan custom initial value', () => {
    const { result } = renderHook(() => useCounter(10))
    expect(result.current.count).toBe(10)
  })

  it('increments count', () => {
    const { result } = renderHook(() => useCounter())
    act(() => result.current.increment())
    expect(result.current.count).toBe(1)
  })

  it('resets count', () => {
    const { result } = renderHook(() => useCounter(5))
    act(() => {
      result.current.increment()
      result.current.increment()
      result.current.reset()
    })
    expect(result.current.count).toBe(5)
  })
})

// Hook dengan dependencies/context
it('useFetchUser works dengan provider', async () => {
  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      <AuthProvider user={mockUser}>
        {children}
      </AuthProvider>
    </QueryClientProvider>
  )

  const { result } = renderHook(() => useFetchUser('user-123'), { wrapper })

  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data).toMatchObject({ id: 'user-123' })
})
```

---

### MSW (Mock Service Worker)

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/users/:id', ({ params }) => {
    const { id } = params
    return HttpResponse.json({
      id,
      email: 'test@test.com',
      name: 'Test User',
    })
  }),

  http.post('/api/users', async ({ request }) => {
    const body = await request.json()
    return HttpResponse.json(
      { id: 'new-user-123', ...body },
      { status: 201 }
    )
  }),

  // GraphQL
  graphql.query('GetUser', ({ variables }) => {
    return HttpResponse.json({
      data: {
        user: { id: variables.id, name: 'Test User' }
      }
    })
  }),

  // Error simulation
  http.delete('/api/users/:id', () => {
    return HttpResponse.json(
      { error: 'Not authorized' },
      { status: 403 }
    )
  }),
]

// src/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'
export const server = setupServer(...handlers)

// src/mocks/browser.ts (untuk development)
import { setupWorker } from 'msw/browser'
export const worker = setupWorker(...handlers)
```

---

### Next.js App Router Testing

```typescript
// Testing Server Components dengan React Testing Library
// next.config.js: experimental.serverComponents: true

import { render, screen } from '@testing-library/react'
import { Suspense } from 'react'
import UserProfile from './UserProfile' // Server Component

// Mock Next.js modules
jest.mock('next/headers', () => ({
  cookies: () => ({ get: jest.fn().mockReturnValue({ value: 'mock-token' }) }),
  headers: () => new Headers()
}))

jest.mock('next/navigation', () => ({
  useRouter: () => ({ push: jest.fn(), refresh: jest.fn() }),
  useSearchParams: () => new URLSearchParams(),
  usePathname: () => '/profile',
}))

it('renders user profile data', async () => {
  // Server Components di RTL: await the component
  const Component = await UserProfile({ params: { id: '123' } })
  render(Component)
  expect(screen.getByText('Test User')).toBeInTheDocument()
})
```

---

## 4. INTEGRATION TESTING

### API Integration dengan Supertest

```typescript
// tests/api/users.test.ts
import request from 'supertest'
import { app } from '../../src/app'
import { prisma } from '../../src/lib/prisma'
import { cleanDatabase, seedTestUser } from '../helpers/db'

describe('POST /api/users', () => {
  beforeEach(async () => {
    await cleanDatabase()
  })

  afterAll(async () => {
    await prisma.$disconnect()
  })

  it('creates user dan returns 201', async () => {
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', `Bearer ${ADMIN_TOKEN}`)
      .send({ email: 'new@test.com', name: 'New User', role: 'USER' })
      .expect('Content-Type', /json/)
      .expect(201)

    expect(res.body).toMatchObject({
      data: {
        email: 'new@test.com',
        name: 'New User',
      }
    })
    expect(res.body.data.id).toBeDefined()
    expect(res.body.data.password).toBeUndefined() // Never expose password!

    // Verify DB state
    const dbUser = await prisma.user.findUnique({
      where: { email: 'new@test.com' }
    })
    expect(dbUser).toBeTruthy()
  })

  it('returns 400 untuk duplicate email', async () => {
    await seedTestUser({ email: 'existing@test.com' })

    const res = await request(app)
      .post('/api/users')
      .set('Authorization', `Bearer ${ADMIN_TOKEN}`)
      .send({ email: 'existing@test.com', name: 'Duplicate' })
      .expect(400)

    expect(res.body.error).toMatch(/email.*already.*exists/i)
  })

  it('returns 401 tanpa auth token', async () => {
    await request(app)
      .post('/api/users')
      .send({ email: 'test@test.com' })
      .expect(401)
  })
})
```

---

### Database Integration dengan Transactions

```typescript
// tests/helpers/db.ts
import { prisma } from '../../src/lib/prisma'

export async function withTransaction<T>(
  fn: (tx: typeof prisma) => Promise<T>
): Promise<T> {
  // Setiap test jalan dalam transaction yang di-rollback
  return new Promise((resolve, reject) => {
    prisma.$transaction(async (tx) => {
      try {
        const result = await fn(tx as any)
        resolve(result)
        throw new Error('ROLLBACK') // Force rollback setelah test
      } catch (err) {
        if ((err as Error).message !== 'ROLLBACK') reject(err)
      }
    }).catch((err) => {
      if (err.message !== 'ROLLBACK') reject(err)
    })
  })
}

// Usage di test:
it('correctly updates user balance', async () => {
  await withTransaction(async (tx) => {
    const user = await tx.user.create({ data: { email: 'tx@test.com', balance: 100 } })
    await userService.deductBalance(user.id, 30, { db: tx })
    const updated = await tx.user.findUnique({ where: { id: user.id } })
    expect(updated?.balance).toBe(70)
    // Transaction auto-rolled back — no cleanup needed
  })
})
```

---

### Testcontainers — Real Database dalam Tests

```typescript
// tests/setup/containers.ts
import { PostgreSqlContainer } from '@testcontainers/postgresql'
import { RedisContainer } from '@testcontainers/redis'
import { GenericContainer } from 'testcontainers'

let pgContainer: Awaited<ReturnType<typeof PostgreSqlContainer.prototype.start>>
let redisContainer: Awaited<ReturnType<typeof RedisContainer.prototype.start>>

export async function startContainers() {
  // Start paralel untuk efisiensi
  ;[pgContainer, redisContainer] = await Promise.all([
    new PostgreSqlContainer('postgres:16-alpine')
      .withDatabase('testdb')
      .withUsername('testuser')
      .withPassword('testpass')
      .start(),
    new RedisContainer('redis:7-alpine').start(),
  ])

  // Set env untuk app
  process.env.DATABASE_URL = pgContainer.getConnectionUri()
  process.env.REDIS_URL = `redis://${redisContainer.getHost()}:${redisContainer.getMappedPort(6379)}`

  // Run migrations
  await runMigrations(process.env.DATABASE_URL)
}

export async function stopContainers() {
  await Promise.all([
    pgContainer?.stop(),
    redisContainer?.stop(),
  ])
}

// jest.config.ts — global setup
// globalSetup: './tests/setup/global-setup.ts'
// globalTeardown: './tests/setup/global-teardown.ts'

// global-setup.ts
export default async function() {
  await startContainers()
}
```

---

### Testing Auth Middleware

```typescript
describe('JWT Auth Middleware', () => {
  it('passes valid token', async () => {
    const token = jwt.sign({ userId: 'user-123', role: 'USER' }, process.env.JWT_SECRET!, {
      expiresIn: '1h'
    })

    const res = await request(app)
      .get('/api/protected-resource')
      .set('Authorization', `Bearer ${token}`)
      .expect(200)
  })

  it('rejects expired token', async () => {
    const token = jwt.sign({ userId: 'user-123' }, process.env.JWT_SECRET!, {
      expiresIn: '-1s' // Already expired
    })

    const res = await request(app)
      .get('/api/protected-resource')
      .set('Authorization', `Bearer ${token}`)
      .expect(401)

    expect(res.body.error).toMatch(/token.*expired/i)
  })

  it('rejects manipulated token', async () => {
    const token = 'eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiJhZG1pbiJ9.FAKE_SIGNATURE'

    await request(app)
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${token}`)
      .expect(401)
  })

  it('enforces RBAC — USER gak bisa akses ADMIN route', async () => {
    const userToken = jwt.sign({ userId: 'user-123', role: 'USER' }, process.env.JWT_SECRET!)

    await request(app)
      .delete('/api/admin/users/someone')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(403)
  })
})
```

---

## 5. END-TO-END TESTING DENGAN PLAYWRIGHT

### Playwright Config

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results.json' }],
    process.env.CI ? ['github'] : ['list'],
  ],

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry', // Capture trace untuk debugging failures
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10000,
    navigationTimeout: 30000,
  },

  projects: [
    // Setup project — run auth first
    { name: 'setup', testMatch: /.*\.setup\.ts/ },

    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'e2e/.auth/user.json', // Reuse auth state
      },
      dependencies: ['setup'],
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 13'] },
    },
  ],

  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
})
```

---

### Page Object Model (POM)

```typescript
// e2e/pages/LoginPage.ts
import { Page, Locator, expect } from '@playwright/test'

export class LoginPage {
  readonly page: Page
  readonly emailInput: Locator
  readonly passwordInput: Locator
  readonly submitButton: Locator
  readonly errorMessage: Locator

  constructor(page: Page) {
    this.page = page
    this.emailInput = page.getByLabel('Email')
    this.passwordInput = page.getByLabel('Password')
    this.submitButton = page.getByRole('button', { name: /sign in/i })
    this.errorMessage = page.getByRole('alert')
  }

  async goto() {
    await this.page.goto('/login')
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email)
    await this.passwordInput.fill(password)
    await this.submitButton.click()
  }

  async loginAndWait(email: string, password: string) {
    await this.login(email, password)
    await this.page.waitForURL('/dashboard')
  }

  async expectError(message: string | RegExp) {
    await expect(this.errorMessage).toBeVisible()
    await expect(this.errorMessage).toHaveText(message)
  }
}

// e2e/pages/DashboardPage.ts
export class DashboardPage {
  constructor(readonly page: Page) {}

  get welcomeMessage() {
    return this.page.getByRole('heading', { name: /welcome/i })
  }

  get logoutButton() {
    return this.page.getByRole('button', { name: /logout/i })
  }

  async navigateTo(section: 'profile' | 'settings' | 'billing') {
    await this.page.getByRole('link', { name: section }).click()
    await this.page.waitForURL(`/${section}`)
  }
}

// e2e/tests/auth.spec.ts
import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/LoginPage'
import { DashboardPage } from '../pages/DashboardPage'

test.describe('Authentication Flow', () => {
  let loginPage: LoginPage

  test.beforeEach(async ({ page }) => {
    loginPage = new LoginPage(page)
    await loginPage.goto()
  })

  test('successful login redirects ke dashboard', async ({ page }) => {
    const dashboard = new DashboardPage(page)
    await loginPage.loginAndWait('user@test.com', 'password123')
    await expect(dashboard.welcomeMessage).toBeVisible()
  })

  test('invalid credentials shows error', async () => {
    await loginPage.login('wrong@test.com', 'wrongpass')
    await loginPage.expectError(/invalid email or password/i)
  })
})
```

---

### Auth State Management

```typescript
// e2e/auth.setup.ts
import { test as setup, expect } from '@playwright/test'
import path from 'path'

const authFile = path.join(__dirname, '.auth/user.json')

setup('authenticate', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill('user@test.com')
  await page.getByLabel('Password').fill('password123')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL('/dashboard')

  // Save auth state — cookies + localStorage
  await page.context().storageState({ path: authFile })
})

// e2e/auth-admin.setup.ts — multiple auth states
setup('authenticate as admin', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill('admin@test.com')
  await page.getByLabel('Password').fill('admin123')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL('/admin')
  await page.context().storageState({ path: '.auth/admin.json' })
})
```

---

### Network Mocking & API Interception

```typescript
test('shows loading state dan renders data', async ({ page }) => {
  // Intercept API call, add delay untuk test loading state
  await page.route('/api/users', async (route) => {
    await new Promise(resolve => setTimeout(resolve, 500))
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        data: [{ id: '1', name: 'Test User', email: 'test@test.com' }]
      })
    })
  })

  await page.goto('/users')
  await expect(page.getByTestId('loading-spinner')).toBeVisible()
  await expect(page.getByText('Test User')).toBeVisible()
})

test('handles API error gracefully', async ({ page }) => {
  await page.route('/api/users', route => {
    route.fulfill({ status: 500, body: '{"error":"Internal Server Error"}' })
  })

  await page.goto('/users')
  await expect(page.getByRole('alert')).toContainText(/something went wrong/i)
  await expect(page.getByRole('button', { name: /retry/i })).toBeVisible()
})
```

---

### Playwright vs Cypress — Trade-offs

| Aspek | Playwright | Cypress |
|-------|------------|---------|
| Browser Support | Chromium, Firefox, WebKit | Chrome, Firefox, Edge |
| Multi-tab | ✅ Native | ❌ Tidak support |
| Parallel execution | ✅ Built-in, fast | ⚠️ Paid feature (Cypress Cloud) |
| Mobile emulation | ✅ Real emulation | ⚠️ Terbatas |
| Speed | ⚡ Faster (no iframe) | 🐌 Lebih lambat |
| Debugging | Trace Viewer, Time-travel | Time-travel di GUI |
| DX (developer experience) | Good, improving | Excellent GUI |
| Flakiness | Lower (auto-wait) | Medium |
| Network mocking | `page.route()` | `cy.intercept()` |
| CI setup | Mudah, Docker image ada | Mudah |

**Verdict**: Playwright untuk new projects. Cypress kalau team sudah invest banyak.

---

## 6. API TESTING

### k6 Load Testing

```javascript
// load-test.js
import http from 'k6/http'
import { check, sleep } from 'k6'
import { Rate, Trend } from 'k6/metrics'

// Custom metrics
const errorRate = new Rate('errors')
const loginDuration = new Trend('login_duration', true)

export let options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp up ke 10 VUs
    { duration: '1m', target: 100 },   // Ramp up ke 100 VUs
    { duration: '2m', target: 100 },   // Stay at 100 VUs
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'], // 95% request < 500ms
    http_req_failed: ['rate<0.01'],                  // Error rate < 1%
    errors: ['rate<0.05'],
    login_duration: ['p(95)<800'],
  },
}

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000'

export function setup() {
  // Run once sebelum test — seed data, get tokens
  const loginRes = http.post(`${BASE_URL}/api/auth/login`, JSON.stringify({
    email: 'loadtest@test.com',
    password: 'password123',
  }), { headers: { 'Content-Type': 'application/json' } })

  return { token: loginRes.json('token') }
}

export default function(data) {
  const headers = {
    'Authorization': `Bearer ${data.token}`,
    'Content-Type': 'application/json',
  }

  // Scenario 1: Get users list
  const listRes = http.get(`${BASE_URL}/api/users`, { headers })
  check(listRes, {
    'list status 200': (r) => r.status === 200,
    'list has data': (r) => r.json('data').length > 0,
  })
  errorRate.add(listRes.status !== 200)

  sleep(1)

  // Scenario 2: Create user
  const startTime = Date.now()
  const createRes = http.post(`${BASE_URL}/api/users`, JSON.stringify({
    email: `user-${Date.now()}@test.com`,
    name: 'Load Test User',
  }), { headers })
  loginDuration.add(Date.now() - startTime)

  check(createRes, {
    'create status 201': (r) => r.status === 201,
  })

  sleep(Math.random() * 3) // Random think time
}

export function teardown(data) {
  // Cleanup setelah load test
  console.log('Load test completed')
}
```

Jalankan: `k6 run --vus 50 --duration 30s load-test.js`

---

### API Contract Testing dengan Pact

```typescript
// consumer side: pact.consumer.test.ts
import { PactV3, MatchersV3 } from '@pact-foundation/pact'

const provider = new PactV3({
  consumer: 'frontend-app',
  provider: 'user-api',
  dir: './pacts',
})

describe('UserAPI Contract', () => {
  it('gets user by id', async () => {
    await provider.addInteraction({
      uponReceiving: 'a request for user 123',
      withRequest: {
        method: 'GET',
        path: '/api/users/123',
        headers: { Authorization: MatchersV3.regex('Bearer .+', 'Bearer token123') }
      },
      willRespondWith: {
        status: 200,
        body: {
          id: MatchersV3.string('123'),
          email: MatchersV3.email('test@test.com'),
          name: MatchersV3.string('Test User'),
        }
      }
    })

    await provider.executeTest(async (mockProvider) => {
      const client = new UserApiClient(mockProvider.url)
      const user = await client.getUser('123')
      expect(user.email).toBeDefined()
    })
  })
})
```

---

## 7. PERFORMANCE ENGINEERING

### Core Web Vitals — Targets & Measurement

```
LCP (Largest Contentful Paint): < 2.5s   ← loading performance
CLS (Cumulative Layout Shift): < 0.1     ← visual stability
INP (Interaction to Next Paint): < 200ms ← responsiveness (replaced FID)
```

**Common LCP culprits & fixes**:
```typescript
// ❌ Slow: LCP element loaded late
<img src="/hero.jpg" />

// ✅ Fix: preload + explicit dimensions
<link rel="preload" as="image" href="/hero.jpg" />
<img
  src="/hero.jpg"
  width={1200}
  height={600}
  priority // Next.js: preload this image
  fetchPriority="high"
/>

// ❌ Slow: Large JS blocking render
// ✅ Fix: Dynamic imports
const HeavyChart = dynamic(() => import('./HeavyChart'), {
  loading: () => <ChartSkeleton />,
  ssr: false
})
```

**CLS fixes**:
```css
/* Reserve space untuk dynamic content */
.ad-slot {
  min-height: 250px; /* Avoid layout shift ketika ad loads */
}

/* Explicit dimensions untuk semua images */
img {
  aspect-ratio: attr(width) / attr(height);
}
```

---

### Lighthouse CI — Automated Perf Audits

```yaml
# .lighthouserc.yaml
ci:
  collect:
    url:
      - http://localhost:3000
      - http://localhost:3000/products
      - http://localhost:3000/checkout
    numberOfRuns: 3
    startServerCommand: 'pnpm build && pnpm start'
    startServerReadyPattern: 'Ready in'

  assert:
    assertions:
      first-contentful-paint:
        - warn
        - maxNumericValue: 2000
      largest-contentful-paint:
        - error
        - maxNumericValue: 2500
      cumulative-layout-shift:
        - error
        - maxNumericValue: 0.1
      interactive:
        - error
        - maxNumericValue: 5000
      'categories:performance':
        - error
        - minScore: 0.8
      'categories:accessibility':
        - error
        - minScore: 0.9

  upload:
    target: temporary-public-storage # atau LHCI server
```

```yaml
# GitHub Actions
- name: Lighthouse CI
  run: |
    npm install -g @lhci/cli@0.14.x
    lhci autorun
  env:
    LHCI_GITHUB_APP_TOKEN: ${{ secrets.LHCI_GITHUB_APP_TOKEN }}
```

---

### Bundle Analysis

```typescript
// next.config.ts
import withBundleAnalyzer from '@next/bundle-analyzer'

const bundleAnalyzer = withBundleAnalyzer({
  enabled: process.env.ANALYZE === 'true',
  openAnalyzer: false,
})

export default bundleAnalyzer({
  // your config
})
```

Jalankan: `ANALYZE=true pnpm build`

**Yang harus dicek**:
- Duplicate packages (lodash vs lodash-es)
- Unexpected large chunks (moment.js = 230KB — replace dengan date-fns)
- Client-side imports yang harusnya server-only
- Third-party scripts yang bloat bundle

```typescript
// Catch bundle bloat dengan size-limit
// package.json
{
  "size-limit": [
    {
      "path": ".next/static/chunks/main-*.js",
      "limit": "200 KB"
    },
    {
      "path": ".next/static/chunks/pages/index-*.js",
      "limit": "50 KB"
    }
  ]
}
// CI: pnpm size-limit
```

---

### React Performance — Profiling & Optimization

```tsx
// React DevTools Profiler
// Install: Browser extension React DevTools
// Record renders, lihat flame chart

// why-did-you-render — log unnecessary re-renders di dev
// _app.tsx
if (process.env.NODE_ENV === 'development') {
  const whyDidYouRender = require('@welldone-software/why-did-you-render')
  whyDidYouRender(React, {
    trackAllPureComponents: true,
    trackHooks: true,
    logOnDifferentValues: true,
  })
}

// Mark component untuk tracking
UserList.whyDidYouRender = true

// useTransition — non-urgent updates (React 18+)
function SearchPage() {
  const [query, setQuery] = useState('')
  const [isPending, startTransition] = useTransition()
  const [results, setResults] = useState([])

  function handleSearch(value: string) {
    setQuery(value) // Urgent — update input immediately

    startTransition(() => {
      // Non-urgent — bisa di-interrupt
      setResults(expensiveSearch(value))
    })
  }

  return (
    <>
      <input value={query} onChange={e => handleSearch(e.target.value)} />
      {isPending && <Spinner />}
      <SearchResults results={results} />
    </>
  )
}

// useDeferredValue — defer low-priority renders
function SearchResults({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query)
  const isStale = query !== deferredQuery

  return (
    <div style={{ opacity: isStale ? 0.7 : 1 }}>
      <SlowList query={deferredQuery} />
    </div>
  )
}
```

---

### Virtualization — Render Only What's Visible

```tsx
// TanStack Virtual — the modern choice
import { useVirtualizer } from '@tanstack/react-virtual'

function VirtualizedList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null)

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 60, // Estimated row height
    overscan: 5, // Render extra rows outside viewport
  })

  return (
    <div ref={parentRef} style={{ height: '600px', overflow: 'auto' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            data-index={virtualItem.index}
            ref={virtualizer.measureElement}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <ListItem item={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  )
}
// Render 50 items dari 100.000 — smooth scrolling
```

---

### Node.js Backend Profiling

```bash
# 1. CPU profiling dengan --prof
node --prof server.js
# Jalankan load test, terus:
node --prof-process isolate-*.log > processed.txt

# 2. 0x — flamegraph yang readable
npx 0x server.js
# Buka http://localhost:5000 — visual flamegraph

# 3. clinic.js — comprehensive profiling
npx clinic doctor -- node server.js   # Overall health check
npx clinic bubbleprof -- node server.js # Async analysis
npx clinic flame -- node server.js    # CPU flamegraph

# 4. Memory leak detection
node --inspect server.js
# Chrome DevTools → Memory → Take heap snapshot
# Jalankan workload → snapshot lagi → compare

# Heap dump programmatic
import v8 from 'v8'
import fs from 'fs'

setInterval(() => {
  const snapshot = v8.writeHeapSnapshot()
  console.log(`Heap snapshot: ${snapshot}`)
}, 60000) // Every minute
```

---

### Database Query Profiling

```sql
-- PostgreSQL EXPLAIN ANALYZE
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT u.*, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.created_at > NOW() - INTERVAL '30 days'
GROUP BY u.id;

-- Baca hasilnya:
-- Sequential Scan → needs index
-- Seq Scan on orders (cost=0.00..45000.00 rows=1000000) → 1M rows scan = bad
-- Index Scan → good

-- Add index
CREATE INDEX CONCURRENTLY idx_users_created_at ON users(created_at DESC);
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);

-- Monitor slow queries (postgresql.conf)
-- log_min_duration_statement = 1000  # Log queries > 1s
-- pg_stat_statements extension untuk aggregated stats
```

```typescript
// Prisma query logging
const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'query' },
    { emit: 'stdout', level: 'error' },
  ]
})

prisma.$on('query', (e) => {
  if (e.duration > 100) { // Log slow queries > 100ms
    console.warn(`Slow query (${e.duration}ms):`, e.query)
    console.warn('Params:', e.params)
  }
})
```

---

## 8. MONITORING & ALERTING

### Sentry Integration

```typescript
// sentry.server.config.ts
import * as Sentry from '@sentry/nextjs'

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  profilesSampleRate: 0.1,

  integrations: [
    new Sentry.Integrations.Prisma({ client: prisma }),
    new Sentry.Integrations.Http({ tracing: true }),
  ],

  beforeSend(event, hint) {
    // Filter out noise
    if (event.exception?.values?.[0]?.type === 'CanceledError') return null
    return event
  }
})

// Enriching errors dengan context
async function createOrder(userId: string, items: CartItem[]) {
  return Sentry.withScope(async (scope) => {
    scope.setUser({ id: userId })
    scope.setTag('feature', 'checkout')
    scope.setContext('cart', { itemCount: items.length, total: calculateTotal(items) })

    try {
      return await orderService.create({ userId, items })
    } catch (error) {
      scope.setLevel('error')
      Sentry.captureException(error)
      throw error
    }
  })
}

// React Error Boundary + Sentry
import { ErrorBoundary } from '@sentry/react'

function App() {
  return (
    <ErrorBoundary
      fallback={({ error, resetError }) => (
        <ErrorPage message={error.message} onRetry={resetError} />
      )}
      onError={(error, componentStack) => {
        Sentry.captureException(error, { contexts: { react: { componentStack } } })
      }}
    >
      <Router />
    </ErrorBoundary>
  )
}
```

---

### Source Maps Upload di CI

```yaml
# .github/workflows/deploy.yml
- name: Build
  run: pnpm build
  env:
    NEXT_PUBLIC_SENTRY_DSN: ${{ secrets.SENTRY_DSN }}

- name: Upload Source Maps ke Sentry
  run: |
    npx @sentry/cli releases new ${{ github.sha }}
    npx @sentry/cli releases files ${{ github.sha }} \
      upload-sourcemaps .next/static --url-prefix '~/_next/static'
    npx @sentry/cli releases finalize ${{ github.sha }}
    npx @sentry/cli releases deploys ${{ github.sha }} new -e production
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: your-org
    SENTRY_PROJECT: your-project
```

---

## 9. CODE QUALITY TOOLS

### ESLint Flat Config (ESLint v9+)

```javascript
// eslint.config.js
import tseslint from 'typescript-eslint'
import reactHooks from 'eslint-plugin-react-hooks'
import jsxA11y from 'eslint-plugin-jsx-a11y'
import importPlugin from 'eslint-plugin-import'

export default tseslint.config(
  // Base TypeScript config
  ...tseslint.configs.recommendedTypeChecked,

  {
    languageOptions: {
      parserOptions: {
        project: './tsconfig.json',
        tsconfigRootDir: import.meta.dirname,
      }
    },

    plugins: {
      'react-hooks': reactHooks,
      'jsx-a11y': jsxA11y,
      'import': importPlugin,
    },

    rules: {
      // TypeScript strict
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unsafe-assignment': 'error',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/prefer-nullish-coalescing': 'error',
      '@typescript-eslint/prefer-optional-chain': 'error',

      // React Hooks
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',

      // Accessibility
      'jsx-a11y/alt-text': 'error',
      'jsx-a11y/anchor-is-valid': 'error',

      // Import order
      'import/order': ['error', {
        groups: ['builtin', 'external', 'internal', 'parent', 'sibling'],
        'newlines-between': 'always',
        alphabetize: { order: 'asc' }
      }],

      // Custom rules
      'no-console': ['warn', { allow: ['error', 'warn'] }],
    }
  },

  // Relax rules untuk test files
  {
    files: ['**/*.test.ts', '**/*.test.tsx', '**/*.spec.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unsafe-assignment': 'off',
    }
  }
)
```

---

### Husky + lint-staged + Commitlint

```json
// package.json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md,yaml}": ["prettier --write"]
  }
}
```

```bash
# Setup
pnpm add -D husky lint-staged commitlint @commitlint/config-conventional
npx husky init

# .husky/pre-commit
#!/bin/sh
pnpm lint-staged

# .husky/commit-msg
#!/bin/sh
npx --no -- commitlint --edit $1
```

```javascript
// commitlint.config.js
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'docs', 'style', 'refactor',
      'perf', 'test', 'build', 'ci', 'chore', 'revert'
    ]],
    'subject-max-length': [2, 'always', 72],
    'body-max-line-length': [2, 'always', 100],
  }
}
// Valid: "feat(auth): add OAuth2 login with Google"
// Invalid: "updated stuff" ← commitlint rejects
```

---

### TypeScript Strict Mode

```json
// tsconfig.json — maximum strictness
{
  "compilerOptions": {
    "strict": true,                        // Enables: strictNullChecks, noImplicitAny, strictFunctionTypes, etc.
    "noUncheckedIndexedAccess": true,      // arr[0] → T | undefined, bukan T
    "exactOptionalPropertyTypes": true,    // { a?: string } gak bisa set { a: undefined }
    "noPropertyAccessFromIndexSignature": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitOverride": true,
    "forceConsistentCasingInFileNames": true,
    "verbatimModuleSyntax": true,          // import type enforcement
  }
}
```

---

## 10. SECURITY TESTING

### Dependency Vulnerability Scanning

```bash
# npm audit — built-in
npm audit
npm audit --audit-level=high  # Fail hanya untuk high/critical
npm audit fix                 # Auto-fix safe updates
npm audit fix --force         # Breaking changes (review first!)

# Snyk — lebih comprehensive
npx snyk test
npx snyk test --severity-threshold=high
npx snyk monitor  # Continuous monitoring
```

```yaml
# .github/workflows/security.yml
- name: Run Snyk
  uses: snyk/actions/node@master
  env:
    SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
  with:
    args: --severity-threshold=high --fail-on=all

# Dependabot (otomatis dari GitHub)
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
    groups:
      dev-dependencies:
        patterns: ['@types/*', 'eslint*', 'prettier*']
    ignore:
      - dependency-name: '*'
        update-types: ['version-update:semver-major']
```

---

### SAST dengan Semgrep

```yaml
# .semgrep.yml — custom security rules
rules:
  - id: no-hardcoded-secrets
    patterns:
      - pattern: |
          const $KEY = "..."
      - metavariable-regex:
          metavariable: $KEY
          regex: '(?i)(password|secret|token|api_key|apikey)'
    message: "Hardcoded secret detected: $KEY"
    severity: ERROR
    languages: [typescript, javascript]

  - id: sql-injection-risk
    pattern: |
      db.query(`... ${$INPUT} ...`)
    message: "Possible SQL injection — use parameterized queries"
    severity: WARNING
    languages: [typescript]

  - id: jwt-algorithm-none
    pattern: |
      jwt.verify($TOKEN, $SECRET, { algorithms: ["none"] })
    message: "JWT 'none' algorithm is insecure"
    severity: ERROR
    languages: [typescript]
```

```bash
# Jalankan Semgrep
semgrep --config=.semgrep.yml --config=p/owasp-top-ten src/

# CI integration
semgrep ci --config=p/typescript --config=p/security-audit
```

---

### Secret Scanning

```bash
# truffleHog — scan git history untuk exposed secrets
trufflehog git https://github.com/org/repo --only-verified
trufflehog filesystem ./src --exclude-paths .gitignore

# git-secrets — prevent committing secrets
git secrets --install  # Install hooks
git secrets --register-aws  # AWS credentials patterns
git secrets --add 'sk-[a-zA-Z0-9]{48}'  # OpenAI API key pattern

# Pre-commit hook
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
```

---

### OWASP Top 10 — Testing Checklist

```typescript
// A01: Broken Access Control — test authorization
describe('Authorization checks', () => {
  it('user cannot access other user data', async () => {
    const userToken = await loginAs('user-a@test.com')
    const res = await request(app)
      .get('/api/users/user-b-id/private-data')
      .set('Authorization', `Bearer ${userToken}`)
    expect(res.status).toBe(403)
  })

  it('IDOR protection — cannot modify by guessing ID', async () => {
    const res = await request(app)
      .put('/api/orders/1') // Brute force sequentialID
      .set('Authorization', `Bearer ${OTHER_USER_TOKEN}`)
      .send({ status: 'CANCELLED' })
    expect(res.status).toBe(403)
  })
})

// A03: Injection — test input sanitization
it('prevents SQL injection', async () => {
  const res = await request(app)
    .get('/api/users')
    .query({ search: "'; DROP TABLE users; --" })
  // Harusnya return empty results, bukan error 500
  expect(res.status).toBe(200)
  expect(res.body.data).toEqual([])
})

// A07: XSS — test output encoding
it('sanitizes stored XSS', async () => {
  const maliciousName = '<script>alert("xss")</script>Legit Name'
  const createRes = await request(app)
    .post('/api/products')
    .send({ name: maliciousName })

  const getRes = await request(app).get(`/api/products/${createRes.body.id}`)
  expect(getRes.body.name).not.toContain('<script>')
})
```

---

## QUICK REFERENCE: CI Pipeline Testing

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: 24, cache: 'pnpm' }

      - run: pnpm install --frozen-lockfile

      # Static checks (fast)
      - run: pnpm typecheck
      - run: pnpm lint

      # Unit + Integration
      - run: pnpm test --coverage --runInBand
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/testdb

      # Upload coverage
      - uses: codecov/codecov-action@v4

      # E2E (parallel)
      - run: pnpm playwright install --with-deps chromium
      - run: pnpm e2e
        env: { CI: 'true', BASE_URL: 'http://localhost:3000' }

      # Security
      - run: npm audit --audit-level=high
      - run: npx semgrep ci --config=p/typescript

      # Performance (on main only)
      - if: github.ref == 'refs/heads/main'
        run: lhci autorun
```

---

## KEY METRICS & TARGETS

| Layer | Tool | Target |
|-------|------|--------|
| Unit coverage | Jest/Vitest | ≥80% statements, ≥75% branches |
| Integration | Supertest + DB | Key user flows 100% |
| E2E | Playwright | Critical paths, smoke test per deploy |
| LCP | Lighthouse | <2.5s |
| CLS | Lighthouse | <0.1 |
| INP | Chrome DevTools | <200ms |
| API P95 | k6 | <500ms |
| Error rate | Sentry | <0.1% |
| Bundle size | size-limit | Main chunk <200KB |

---

*Generated by Bxploit Knowledge Engine — Testing & Performance Mastery*
*Last updated: 2026*
