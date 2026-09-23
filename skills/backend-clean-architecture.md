# ⚡ SKILL: High-Performance Backend Architecture

## Directory Structure & Layer Separation
```text
src/
├── config/         # Environment variables (Zod validated), DB connections, CORS
├── controllers/    # Request/Response handling (HTTP layer only)
├── services/       # Core business logic layer
├── repositories/   # Direct Database Queries (ORM / Raw SQL)
├── middlewares/    # Auth check, Rate limiting, Error handling, Logging
├── schemas/        # Zod DTO validation schemas
├── routes/         # Endpoint route definitions
├── types/          # Shared TypeScript interfaces
└── utils/          # Logger (Pino/Winston), Helpers
```

## Contract-First & Type-Safe APIs
- REST API: Express / Fastify + Zod payload validation for `req.body`, `req.query`, `req.params`.
- tRPC: End-to-end type-safe RPC endpoints sharing router types with Frontend.
- GraphQL: Type-GraphQL / Nexus with query complexity analysis and depth limiting.
