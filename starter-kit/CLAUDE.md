# MyApp — Project Context

## Stack
[Framework], [Language], [ORM], [Database], [CSS Framework], [Test Framework]

## Commands
- `npm run dev` — Start development server
- `npm run test` — Run test suite
- `npm run test:e2e` — Run end-to-end tests
- `npm run lint` — Run linter
- `npm run build` — Production build

## Architecture
- `/app` — Pages and layouts
- `/lib` — Business logic, API clients
- `/components` — UI components
- `/prisma` — Database schema and migrations
- `/docs` — Pipeline documents (PRFAQ, PRD, HLD, LLD, ADRs)

## Conventions
- Named exports only
- TypeScript strict mode with return types on all functions
- API routes return `{ data, error }` shape
- Conventional Commits for all commit messages
- Tests required for all business logic in `/lib`

## Security
- Never commit `.env` files or secrets
- Validate all external input with Zod
- Webhook endpoints must validate signatures

## Pipeline Documents
- Product docs: `docs/product/`
- Technical design: `docs/design/`
- Architecture decisions: `docs/decisions/`
