# 0001. Feature structure

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-13

## Context

The repo has grown several features with inconsistent internal layouts. `features/auth` and `features/settings` were the established examples, but features had drifted into four folder-name conventions (`*-feature` suffixes), three store-file names (`*.store.ts`, `*.feature.ts`, `*.reducer.ts`), and ad-hoc cross-feature dependencies (duplicated data slices, orchestration scattered between `app/` and feature effects). All features converge on one structure so an agent (or human) can navigate any feature without re-learning it.

## Decision

Every feature lives at `src/features/<feature-name>/` and follows this layout:

```
src/features/<name>/
├── <name>.routes.ts          # lazy routes; route-scoped provideEffects (and provideState if route-scoped)
├── <name>.providers.ts       # ONLY for a global feature (auth, settings, products); registered in app.config.ts
├── <name>.model.ts           # domain models only
├── pages/                    # thin pages, OnPush; route-bound; compose components, read state via selectors
│   └── <page>/
│       ├── <page>.component.{ts,html,scss}
│       └── <page>.selectors.ts
├── components/               # dumb presentational components (input/output only) — only when needed
├── form/                     # smart form components — one subfolder each — only when needed
│   ├── <form>/<form>.component.{ts,html,scss}   # owns FormGroup + form-value interface + validators inline
│   └── validators.ts                           # ONLY for validators shared across multiple forms in the feature
├── services/                 # data-access services
└── +state/
    ├── index.ts              # barrel: re-exports action groups + effects namespaces + store
    ├── <name>.store.ts       # createFeature + createReducer + extraSelectors
    ├── actions/
    │   ├── api.actions.ts        # service results + granular failures
    │   ├── component.actions.ts  # one action group per page/component
    │   ├── routing.actions.ts    # '<Feature> | Router Effects' Successful/Failed nav outcomes
    │   ├── snackbar.actions.ts   # '<Page> Snack Bar' handoffs
    │   └── dialog.actions.ts     # (optional) confirm/abort outcomes for Material dialogs
    └── effects/
        ├── api.effects.ts        # data calls + streaming, mapResponse, catchError -> granular failures
        ├── routing.effects.ts    # navigate + mapResponse -> Successful/Failed routing actions
        ├── snackbar.effects.ts   # MatSnackBar on Api outcomes
        └── dialog.effects.ts     # (optional) open a Material dialog, map result -> confirm/abort
```

### Conventions

- **Folder name:** `src/features/<name>` — not `src/<name>-feature`.
- **Store file:** `<name>.store.ts` (no `*.feature.ts` / `*.reducer.ts`).
- **State split:** one action file per concern under `actions/` (api / component / routing / snackbar, plus `dialog` when a feature opens dialogs). Effects split along the same roles. Concern files and the store are produced _as needed_ — a layout feature with no data slice (shell) omits the store and the api/snackbar/dialog concerns.
- **Barrel:** `+state/index.ts` re-exports all action groups and the store, and re-exports each effects file as a namespace (`export * as apiEffects`), so consumers import from `'feature/+state'` only.
- **Action groups:** `source: '<Feature> | <X>'` e.g. `'Auth | Login Api'`, `'Settings | Account Page'`. Events phrased as completed statements.
- **Effects:** `{ functional: true }`, deps via `inject()` in default params; navigation effects use `mapResponse` emitting `...Successful`/`...Failed` routing actions (no `dispatch: false` silent navigation).
- **Global vs route-scoped:** a feature registers its store + effects globally (via a `*.providers.ts` called from `app.config.ts`, eagerly loaded, never imported by a lazy route) **iff** its state is read outside its own lazy routes or its effects must fire on app-wide events. Otherwise it is route-scoped (`provideState`/`provideEffects` in its `<name>.routes.ts`). Global features: **auth, settings, products**. Route-scoped: shell (layout), current-meal, saved-meals.
- **Cross-feature data access:** a feature reads another feature's state through that feature's store selectors — never by duplicating the slice, service, or subscription. The feature that owns the data is global _because_ others read it (products is global because current-meal's picker reads it). Cross-feature writes/orchestration live in the consuming feature's effects, which inject the owner's service — never navigating on another feature's behalf.
- **Components vs forms:** `components/` holds _dumb_ presentational components — input/output props only, no `Store`, no `FormGroup`, no state. `form/` holds _smart_ form components, one subfolder each, where the `.component.ts` owns its `FormGroup`, its form-value interface, and its validators inline. `form/validators.ts` exists only when a validator is shared across multiple forms in the same feature.
- **Dialog concern:** `dialog.actions.ts` + `dialog.effects.ts` is the optional fifth concern — a confirmation dialog is two-way ("ask and get an answer"), distinct from the one-way `snackbar`. Present only when a feature opens Material dialogs.
- **Model placement:** `<name>.model.ts` holds domain models only (Product, SavedMeal, CurrentMeal). UI contract types (dialog `Data`/`Result`, page view models) live co-located with the component that owns them — a dialog's contract stays in a `*.model.ts` inside the dialog's folder, not the feature-root model.
- **`app/` is bootstrap only:** `app.config.ts`, `app.component.ts`, `app.routes.ts` (root route table + the `isLoggedIn` `canMatch` guard). No `+state/`, no actions/effects/reducer, no services.

## Consequences

- Remaining `src/<name>-feature` folders migrate into `src/features/` one ticket at a time (products #191, current-meal #192, saved-meals #193, shell #194).
- `current-meal` and `saved-meals` single-file `+state/` split into `actions/` + `effects/` + a barrel; `*.feature.ts` renamed to `*.store.ts`.
- `products` gains a `+state/index.ts` barrel, renames `products.reducer.ts` → `products.store.ts`, and becomes **global** (`products.providers.ts`, streaming keyed off login/logout). It is the single owner of `Product` data — current-meal drops its own `products` slice, its duplicate `ProductsService`, and its `ProductsApiActions`, and reads products via `productsFeature` selectors.
- `shell` gains a slim `+state/` (component + routing actions, routing effects, barrel — no store).
- `settings` gains `settings.store.ts` + `settings.providers.ts` and becomes global; its streaming effects move from `app.effects.ts` into its own `api.effects.ts`. Its "back to settings" navigation moves into its own `routing.effects.ts` (out of shell).
- `auth` gains the login/signup navigation effects (from `app.effects.ts`) and absorbs `AppRouterEffectsActions` into its `routing.actions.ts`.
- `app/` is reduced to `app.config.ts`, `app.component.ts`, `app.routes.ts`; `app.actions.ts`, `app.effects.ts`, `app.reducer.ts` (+ specs) are deleted.
- `saved-meals`' delete confirmation is split into the `dialog` concern (`dialog.actions` + `dialog.effects`) to match products.
- `current-meal`'s `saveCurrentMealAsSavedMeal` stays in current-meal's effects as cross-feature write orchestration (injects `SavedMealsService` + the name dialog); no saved-meals state is duplicated.
