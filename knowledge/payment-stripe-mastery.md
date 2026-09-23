# 💳 PAYMENT SYSTEMS & STRIPE MASTERY — Bxploit Knowledge Base
**Version:** 1.0.0 | **Category:** Payment Engineering

---

## 1. STRIPE ARCHITECTURE OVERVIEW

```
User Browser
    │
    ├── Stripe.js / Stripe Elements (client-side, PCI-compliant)
    │       └── Tokenizes card → Stripe servers (NEVER touches your server)
    │
    └── Your Frontend → Your Backend API
                            │
                            ├── Stripe Node.js SDK
                            │       └── Create PaymentIntent / Checkout Session
                            │
                            └── Stripe Webhooks → Your Webhook Handler
                                    └── Fulfill orders, update DB
```

**Golden Rule**: Card data NEVER passes through your server. Stripe.js sends card data directly to Stripe and returns a token/PaymentMethod ID.

---

## 2. STRIPE SETUP

```bash
npm install stripe @stripe/stripe-js @stripe/react-stripe-js
```

```typescript
// lib/stripe.ts — server-side client
import Stripe from 'stripe';

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2024-06-20',
  typescript: true,
  telemetry: false,
  maxNetworkRetries: 3, // auto-retry di network error
});

// lib/stripe-client.ts — client-side (lazy load)
import { loadStripe } from '@stripe/stripe-js';
let stripePromise: Promise<Stripe | null>;
export const getStripe = () => {
  if (!stripePromise) {
    stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!);
  }
  return stripePromise;
};
```

---

## 3. CHECKOUT SESSION (Hosted) — Paling Simple

```typescript
// app/api/checkout/route.ts
import { stripe } from '@/lib/stripe';
import { auth } from '@/lib/auth';

export async function POST(req: Request) {
  const session = await auth();
  if (!session) return Response.json({ error: 'Unauthorized' }, { status: 401 });

  const { priceId, quantity = 1 } = await req.json();

  // Cari atau buat Stripe Customer
  let customerId = session.user.stripeCustomerId;
  if (!customerId) {
    const customer = await stripe.customers.create({
      email: session.user.email!,
      name: session.user.name ?? undefined,
      metadata: { userId: session.user.id },
    });
    customerId = customer.id;
    await db.user.update({
      where: { id: session.user.id },
      data: { stripeCustomerId: customer.id },
    });
  }

  const checkoutSession = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: 'subscription',       // atau 'payment' untuk one-time
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity }],
    success_url: `${process.env.APP_URL}/dashboard?success=true&session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.APP_URL}/pricing?canceled=true`,
    metadata: { userId: session.user.id },
    subscription_data: {
      metadata: { userId: session.user.id },
      trial_period_days: 14, // 14 hari free trial
    },
    allow_promotion_codes: true,
    billing_address_collection: 'auto',
    customer_update: { address: 'auto', name: 'auto' },
  });

  return Response.json({ url: checkoutSession.url });
}

// Frontend: redirect ke Stripe
const handleCheckout = async (priceId: string) => {
  const res = await fetch('/api/checkout', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ priceId }),
  });
  const { url } = await res.json();
  window.location.href = url; // redirect ke Stripe hosted page
};
```

---

## 4. STRIPE ELEMENTS (Custom Checkout UI)

```typescript
// components/CheckoutForm.tsx
'use client';
import { useState } from 'react';
import { useStripe, useElements, PaymentElement, AddressElement } from '@stripe/react-stripe-js';

interface CheckoutFormProps {
  clientSecret: string;
  amount: number;
}

export function CheckoutForm({ clientSecret, amount }: CheckoutFormProps) {
  const stripe = useStripe();
  const elements = useElements();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return;

    setIsLoading(true);
    setError(null);

    // Validate form
    const { error: submitError } = await elements.submit();
    if (submitError) {
      setError(submitError.message ?? 'Validation failed');
      setIsLoading(false);
      return;
    }

    // Confirm payment
    const { error: confirmError } = await stripe.confirmPayment({
      elements,
      clientSecret,
      confirmParams: {
        return_url: `${window.location.origin}/payment/success`,
      },
    });

    if (confirmError) {
      setError(confirmError.message ?? 'Payment failed');
    }
    // Jika success, Stripe redirect ke return_url

    setIsLoading(false);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <PaymentElement options={{ layout: 'tabs' }} />
      <AddressElement options={{ mode: 'billing' }} />
      
      {error && <p className="text-red-500 text-sm">{error}</p>}
      
      <button
        type="submit"
        disabled={!stripe || isLoading}
        className="w-full bg-indigo-600 text-white py-3 rounded-lg font-semibold disabled:opacity-50"
      >
        {isLoading ? 'Processing...' : `Pay ${formatCurrency(amount)}`}
      </button>
    </form>
  );
}

// app/checkout/page.tsx
import { Elements } from '@stripe/react-stripe-js';
import { getStripe } from '@/lib/stripe-client';

export default async function CheckoutPage({ searchParams }: { searchParams: { amount: string } }) {
  // Create PaymentIntent di server
  const paymentIntent = await stripe.paymentIntents.create({
    amount: parseInt(searchParams.amount), // dalam cents
    currency: 'usd',
    automatic_payment_methods: { enabled: true },
  });

  return (
    <Elements
      stripe={getStripe()}
      options={{
        clientSecret: paymentIntent.client_secret!,
        appearance: {
          theme: 'night', // atau 'stripe', 'flat'
          variables: {
            colorPrimary: '#6366f1',
            colorBackground: '#0d1117',
            colorText: '#ffffff',
            fontFamily: 'Inter, system-ui, sans-serif',
            borderRadius: '8px',
          },
        },
      }}
    >
      <CheckoutForm clientSecret={paymentIntent.client_secret!} amount={parseInt(searchParams.amount)} />
    </Elements>
  );
}
```

---

## 5. WEBHOOKS — THE MOST IMPORTANT PART

```typescript
// app/api/webhooks/stripe/route.ts
import { stripe } from '@/lib/stripe';
import { headers } from 'next/headers';

export async function POST(req: Request) {
  const body = await req.text(); // HARUS text, bukan json!
  const headersList = headers();
  const sig = headersList.get('stripe-signature')!;

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    return Response.json({ error: 'Invalid signature' }, { status: 400 });
  }

  // Idempotency: check jika event sudah pernah diproses
  const existingEvent = await db.stripeEvent.findUnique({ where: { stripeEventId: event.id } });
  if (existingEvent) {
    return Response.json({ received: true, status: 'already_processed' });
  }

  // Record event dulu (prevent double processing)
  await db.stripeEvent.create({
    data: { stripeEventId: event.id, type: event.type, processed: false },
  });

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutCompleted(session);
        break;
      }
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionUpdate(subscription);
        break;
      }
      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;
        await handleSubscriptionCanceled(subscription);
        break;
      }
      case 'invoice.payment_succeeded': {
        const invoice = event.data.object as Stripe.Invoice;
        await handleInvoicePaymentSucceeded(invoice);
        break;
      }
      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice;
        await handleInvoicePaymentFailed(invoice);
        break;
      }
      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    // Mark as processed
    await db.stripeEvent.update({
      where: { stripeEventId: event.id },
      data: { processed: true },
    });
  } catch (error) {
    console.error(`Error processing webhook ${event.type}:`, error);
    Sentry.captureException(error, { extra: { eventType: event.type, eventId: event.id } });
    // Return 200 agar Stripe tidak retry! Log error tapi acknowledge receipt.
    // Stripe retry otomatis jika kita return 4xx/5xx
  }

  return Response.json({ received: true });
}

// Handler functions
async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const userId = session.metadata?.userId;
  if (!userId) throw new Error('Missing userId in session metadata');

  if (session.mode === 'subscription') {
    const subscription = await stripe.subscriptions.retrieve(session.subscription as string);
    await upsertSubscription(userId, subscription);
  } else if (session.mode === 'payment') {
    await fulfillOrder(userId, session);
  }
}

async function handleSubscriptionUpdate(subscription: Stripe.Subscription) {
  const userId = subscription.metadata?.userId;
  if (!userId) return;
  await upsertSubscription(userId, subscription);
}

async function upsertSubscription(userId: string, subscription: Stripe.Subscription) {
  const priceId = subscription.items.data[0].price.id;
  const plan = await db.plan.findUnique({ where: { stripePriceId: priceId } });

  await db.subscription.upsert({
    where: { stripeSubscriptionId: subscription.id },
    create: {
      userId,
      stripeSubscriptionId: subscription.id,
      stripeCustomerId: subscription.customer as string,
      status: subscription.status,
      planId: plan?.id,
      currentPeriodStart: new Date(subscription.current_period_start * 1000),
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
      cancelAtPeriodEnd: subscription.cancel_at_period_end,
      trialEnd: subscription.trial_end ? new Date(subscription.trial_end * 1000) : null,
    },
    update: {
      status: subscription.status,
      planId: plan?.id,
      currentPeriodStart: new Date(subscription.current_period_start * 1000),
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
      cancelAtPeriodEnd: subscription.cancel_at_period_end,
      trialEnd: subscription.trial_end ? new Date(subscription.trial_end * 1000) : null,
    },
  });
}
```

---

## 6. CUSTOMER PORTAL (Subscription Management)

```typescript
// app/api/billing/portal/route.ts
export async function POST(req: Request) {
  const session = await auth();
  if (!session) return Response.json({ error: 'Unauthorized' }, { status: 401 });

  const user = await db.user.findUnique({ where: { id: session.user.id } });
  if (!user?.stripeCustomerId) {
    return Response.json({ error: 'No billing account found' }, { status: 404 });
  }

  const portalSession = await stripe.billingPortal.sessions.create({
    customer: user.stripeCustomerId,
    return_url: `${process.env.APP_URL}/settings/billing`,
  });

  return Response.json({ url: portalSession.url });
}

// Frontend
const handleManageBilling = async () => {
  const res = await fetch('/api/billing/portal', { method: 'POST' });
  const { url } = await res.json();
  window.location.href = url; // Redirect ke Stripe Customer Portal
};
```

---

## 7. DATABASE SCHEMA UNTUK BILLING

```sql
-- Plans table (sync dari Stripe Products/Prices)
CREATE TABLE plans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  description TEXT,
  stripe_product_id TEXT UNIQUE NOT NULL,
  stripe_price_id   TEXT UNIQUE NOT NULL,
  price_amount      INTEGER NOT NULL, -- dalam cents
  currency          TEXT NOT NULL DEFAULT 'usd',
  interval          TEXT NOT NULL, -- 'month' | 'year'
  interval_count    INTEGER NOT NULL DEFAULT 1,
  features          JSONB DEFAULT '[]',
  is_active         BOOLEAN DEFAULT true,
  created_at        TIMESTAMPTZ DEFAULT now()
);

-- Subscriptions table
CREATE TABLE subscriptions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id                 UUID REFERENCES plans(id),
  stripe_subscription_id  TEXT UNIQUE NOT NULL,
  stripe_customer_id      TEXT NOT NULL,
  status                  TEXT NOT NULL, -- 'active' | 'canceled' | 'past_due' | 'trialing' | 'paused'
  current_period_start    TIMESTAMPTZ NOT NULL,
  current_period_end      TIMESTAMPTZ NOT NULL,
  cancel_at_period_end    BOOLEAN DEFAULT false,
  trial_end               TIMESTAMPTZ,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);

-- Stripe events (idempotency)
CREATE TABLE stripe_events (
  stripe_event_id TEXT PRIMARY KEY,
  type            TEXT NOT NULL,
  processed       BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT now()
);
```

---

## 8. GATE FITUR BERDASARKAN PLAN

```typescript
// lib/subscription.ts
export async function getUserSubscription(userId: string) {
  return db.subscription.findFirst({
    where: {
      userId,
      status: { in: ['active', 'trialing'] },
    },
    include: { plan: true },
    orderBy: { createdAt: 'desc' },
  });
}

export async function checkFeatureAccess(userId: string, feature: string): Promise<boolean> {
  const sub = await getUserSubscription(userId);
  if (!sub || !sub.plan) return false;
  
  const features = sub.plan.features as string[];
  return features.includes(feature);
}

// Middleware untuk route protection
export function requirePlan(planTier: 'pro' | 'enterprise') {
  return async (req: Request, next: NextFunction) => {
    const session = await auth();
    const sub = await getUserSubscription(session!.user.id);
    
    const tierOrder = { free: 0, pro: 1, enterprise: 2 };
    const userTier = sub?.plan?.tier ?? 'free';
    
    if (tierOrder[userTier] < tierOrder[planTier]) {
      return Response.json({
        error: 'Upgrade required',
        requiredPlan: planTier,
        upgradeUrl: '/pricing',
      }, { status: 403 });
    }
  };
}

// React hook untuk feature gating
export function useFeatureAccess(feature: string) {
  const { data: subscription } = trpc.billing.subscription.useQuery();
  const features = subscription?.plan?.features as string[] ?? [];
  return features.includes(feature);
}

// Usage:
const hasAIAccess = useFeatureAccess('ai_generation');
if (!hasAIAccess) return <UpgradePrompt feature="AI Generation" />;
```

---

## 9. TESTING STRIPE WEBHOOKS LOCALLY

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks ke localhost
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Trigger test events
stripe trigger checkout.session.completed
stripe trigger customer.subscription.created
stripe trigger invoice.payment_failed
stripe trigger customer.subscription.deleted

# Test dengan specific payload
stripe trigger payment_intent.succeeded \
  --add payment_intent:metadata.userId=user_123
```

**Test cards**:
```
Success:       4242 4242 4242 4242  (any future expiry, any CVC)
Decline:       4000 0000 0000 0002
3D Secure:     4000 0027 6000 3184
Insufficient:  4000 0000 0000 9995
```

---

## 10. PAYMENT BEST PRACTICES

### DO ✅
- Selalu verify webhook signature sebelum process
- Implement idempotency (check duplicate event ID)
- Use `metadata` untuk link Stripe objects ke internal user/order IDs
- Store `stripeCustomerId` di user table untuk future charges
- Log semua payment events (tanpa card details)
- Handle `payment_failed` webhook: kirim email, retry dengan dunning logic
- Test webhook locally dengan Stripe CLI sebelum deploy

### DON'T ❌
- JANGAN store card numbers (PCI violation!)
- JANGAN create PaymentIntent di client side (secret key exposed!)
- JANGAN fulfill order dari success_url redirect saja (bisa di-bypass) — SELALU rely on webhook
- JANGAN return 500 dari webhook handler jika event sudah diproses (Stripe akan retry forever)
- JANGAN use `amount` dari client request langsung — selalu calculate di server dari price catalog

### Security
```typescript
// ✅ Server calculates amount, bukan client
app.post('/api/checkout', auth, async (req, res) => {
  const { productId } = req.body;
  
  // Fetch price dari DB/Stripe — jangan percaya amount dari client!
  const product = await db.product.findUniqueOrThrow({ where: { id: productId } });
  const amount = product.priceInCents; // trusted server value
  
  const paymentIntent = await stripe.paymentIntents.create({
    amount, // dari server, bukan dari req.body.amount!
    currency: 'usd',
    metadata: { userId: req.user.id, productId },
  });
  
  return res.json({ clientSecret: paymentIntent.client_secret });
});
```

---

*Bxploit Payment Mastery — Lock down the money flow, gas pol, no bugs in prod. 💸🔥*
