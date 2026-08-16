# 0005. E2E smoke testing

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-16

## Context

ADR-0004 pins all logic testing to the state seam (selectors, reducers, effects) and calls component, service, and end-to-end tests out of scope. But the state seam mocks Firestore away, so it cannot prove three things that break the app in production: that Firestore security rules allow the write, that the collection name a service targets actually exists, and that a read round-trips through a real query. The saved-meals feature (#172) shipped with rules that were never deployed and hit "Missing or insufficient permissions" at runtime — exactly the class of failure a unit test cannot catch. A small smoke layer is the carve-out: e2e tests exist to prove a flow crosses the Firestore boundary, not to cover state logic.

## Decision

E2E tests are a smoke layer only: one cross-boundary flow per Firestore collection, run against the Firebase emulators. They are never a coverage strategy. The first smoke test is the saved-meals flow (#187).

- **Framework:** Cypress. Already scaffolded (`apps/carbotracker-e2e`, `@nx/cypress`). The Playwright evaluation is deferred to a future full-e2e prototype (#81), not re-decided here.
- **Orchestration:** `npx firebase emulators:exec 'npx nx e2e carbotracker-e2e' -c apps/carbotracker/firebase.json --import=apps/carbotracker/firebase-data/development`, with `--ui` dropped. `emulators:exec` is the canonical "start emulators, run a command, tear down" tool; the Cypress dev server is nested via the existing `devServerTarget`.
- **Seeding:** import the shared development export; log in as the seeded user (`z@z.com` / `zzzzzz`). Tests are self-cleaning — they delete what they create so re-runs stay deterministic.
- **Sort order:** saved-meals lists alphabetically by name, matching `saved-meals.store.ts`'s sortComparer. This corrects the "newest-first" wording in #172 and #187; no `orderBy` or composite index is needed.
- **CI:** manual only for now. An optional, non-blocking pipeline check is a follow-up issue, not part of this decision.

## Considered options

- **Full e2e coverage:** rejected — contradicts ADR-0004 and makes the suite slow and flaky for no gain in state logic.
- **Playwright:** rejected for now — the smoke layer is single-origin and single-browser, where Cypress's weaknesses don't apply; Playwright's advantages (cross-browser, service-worker control, network interception, multi-tab) matter for a future full-e2e prototype, not here.
- **Newest-first sort via `orderBy(createdAt)` + composite index:** rejected — the query already streams all of a user's saved meals, so server-side ordering buys nothing; sorting by name client-side is already implemented and matches the intended UX.

## Consequences

- `CODING_STANDARDS.md` gains an "E2E smoke tests" section describing when to write one and where it lives.
- #187 is implemented as the first smoke test; #172 and #187 wording is corrected to alphabetical.
- Two follow-ups: a pipeline e2e setup issue (optional check) and a human grilling issue to prototype a full e2e test for the products feature.
