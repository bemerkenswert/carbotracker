# 0001. Feature structure

- **Status:** Proposed (to be adjusted after discussion ticket #190)
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-09

## Context

The repo has grown several features with inconsistent internal layouts. Two features — `features/auth` and `features/settings` — are the established best-practice examples. All features should converge on the same structure so an agent (or human) can navigate any feature without re-learning it.

## Decision

Every feature lives at `src/features/<feature-name>/` and follows this layout:

```
src/features/<name>/
├── <name>.routes.ts          # lazy routes; route-scoped provideEffects (and provideState if feature-owned)
├── <name>.providers.ts       # ONLY for a feature whose store+effects are global (auth); otherwise route-provided
├── <name>.model.ts           # domain models
├── pages/                    # thin pages, OnPush; route-bound; compose components
│   └── <page>/<page>.component.{ts,html,scss}
├── components/               # presentational components reused by pages (only when needed)
├── form/                     # custom form validators (only when needed)
├── services/                 # data-access services
└── +state/
    ├── index.ts              # barrel: re-exports actions + exports effects namespaces + store
    ├── <name>.store.ts       # createFeature + createReducer + extraSelectors (when feature-owned)
    ├── actions/
    │   ├── api.actions.ts        # service results + granular failures
    │   ├── component.actions.ts  # one action group per page/component
    │   ├── routing.actions.ts    # '<Feature> | Router Effects' Successful/Failed nav outcomes
    │   └── snackbar.actions.ts   # '<Page> Snack Bar' handoffs
    └── effects/
        ├── api.effects.ts        # data calls, mapResponse, catchError -> granular failures
        ├── routing.effects.ts    # navigate + mapResponse -> Successful/Failed routing actions
        └── snackbar.effects.ts   # MatSnackBar on Api outcomes
```

### Conventions

- **Folder name:** `src/features/<name>` — not `src/<name>-feature`.
- **State split:** exactly one action file per concern under `actions/` (api / component / routing / snackbar). Effects split along the same four roles.
- **Barrel:** `+state/index.ts` re-exports all action groups and the store, and re-exports each effects file as a namespace (`export * as apiEffects`), so consumers import from `'feature/+state'` only.
- **Action groups:** `source: '<Feature> | <X>'` e.g. `'Auth | Login Api'`, `'Settings | Account Page'`. Events phrased as completed statements.
- **Effects:** `{ functional: true }`, deps via `inject()` in default params; navigation effects use `mapResponse` emitting `...Successful`/`...Failed` routing actions.
- **Global vs route-scoped:** only a feature that must exist across many routes registers state/effects globally via a `*.providers.ts`; otherwise route-scoped `provideState`/`provideEffects` in the routes file.
- **Cross-feature orchestration** (login → products, settings streaming) lives in the consuming feature's effects or `app/` effects — decide per case during migration, don't duplicate.

## Consequences

- Remaining `src/<name>-feature` folders migrate into `src/features/` one ticket at a time.
- `current-meal` and `saved-meals` single-file `+state/` split into the `actions/` + `effects/` layout with a barrel.
- `products` gains a `+state/index.ts` barrel.
- `shell` gains a `+state/` (currently flat `shell.actions.ts`/`shell.effects.ts`).
- Feature-local vs app-level effects get re-decided as part of migration (e.g. settings streaming currently lives in `app.effects.ts`).

## Status note

This ADR is a first cut from the auth/settings examples. A discussion ticket precedes any migration and is expected to adjust this document before the migration tickets run.
