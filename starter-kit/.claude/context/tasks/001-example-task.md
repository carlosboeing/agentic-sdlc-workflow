# Task 001: Billing API Endpoint

## Source Documents
- PRD: notion-def456 (Section 3.2: Subscription Creation)
- HLD: notion-ghi789 (Component: Billing Service)
- LLD: notion-jkl012 (API: POST /api/billing/create-subscription)
- ADR-001: notion-adr001 (Stripe API over Paddle)

## Parent Story
- PM Issue #42: "As a user, I can subscribe to a plan"

## Relevant Files
- app/api/billing/ (existing billing routes for patterns)
- lib/stripe.ts (existing Stripe client)
- prisma/schema.prisma (current billing models)

## Objective
Create POST /api/billing/create-subscription endpoint

## Acceptance Criteria
- [ ] Accepts { priceId, customerId } body
- [ ] Validates input with Zod (per LLD Section 4.1)
- [ ] Creates Stripe subscription via lib/stripe.ts (per ADR-001)
- [ ] Returns { subscriptionId, clientSecret }
- [ ] 400 on invalid input, 500 on Stripe error (per LLD Section 4.3)
- [ ] Unit tests for happy path plus errors
- [ ] CHANGELOG.md updated

## Dependencies
- None (Wave 1 — parallelizable)
