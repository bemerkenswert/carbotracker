# Carbotracker Agent Guide

## Workspace and Commands

- This is an npm-locked Nx workspace; use Node `v22.21.1` (`.nvmrc`) and install with `npm ci`. Do not use pnpm, Yarn, or Bun.
- Projects are `carbotracker` (Angular application), `carbotracker-e2e` (Cypress), `ui`, and `utility` (Angular/Jest libraries). Target the smallest project with `npx nx <target> <project>`.
- Focused checks: `npx nx lint <project>`, `npx nx test <project>`, `npx nx build carbotracker`, and `npx nx e2e carbotracker-e2e`.
- Run the production-validation sequence used by pull requests in this order: `npm run prettier:check`, `npm run ci:lint`, `npm run ci:test`, then `npm run ci:build:pullrequest`. The `ci:*` commands compare against `origin/main`.
- `npm run start:carbotracker` runs the development Angular server but expects Firebase emulators already available. Use `npm run start:carbotracker:local` for normal local development: it starts Firebase emulators and imports `apps/carbotracker/firebase-data/development`.

## Application Structure

- The application starts at `apps/carbotracker/src/main.ts`; root providers and the auth-gated `app` route are in `src/app/app.config.ts`.
- Feature routes are lazy-loaded from `shell-feature/shell.routes.ts`. Keep feature NgRx state and effects route-scoped with `provideState`/`provideEffects`, following `products-feature/products.routes.ts` and `current-meal-feature/current-meal.routes.ts`; auth is the exception, registered globally through `features/auth/auth.providers.ts`.
- Reusable UI and utilities live in `libs/ui` and `libs/utility`. Consume their public barrels via `@carbotracker/ui` and `@carbotracker/utility`; update each `src/index.ts` when exposing a new shared API.
- App builds write to `apps/carbotracker/.dist`, which Firebase Hosting deploys from `apps/carbotracker/firebase.json`. Do not assume the usual workspace-level `dist/` path.

## Firebase and Tests

- The development environment connects to Auth (`9099`) and Firestore (`8080`) emulators; production and PR-preview builds use the hosted Firebase project. Preserve the environment replacement setup in `apps/carbotracker/project.json` when changing Firebase configuration.
- Cypress e2e starts the Angular development server itself, but that build still connects to Firebase emulators. Start emulators separately before e2e when needed.
- Angular Jest setup rejects unknown template elements and properties (`apps/carbotracker/src/test-setup.ts`); tests must declare or mock their template dependencies rather than relying on permissive schemas.
