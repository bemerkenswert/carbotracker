# Carbotracker coding standards

This document is the living, enforceable "what to do now" reference for carbotracker's code. It is the concrete file the review loop's Standards axis points at. Decisions behind these rules are recorded in `docs/adr/` — see `docs/adr/0004-testing-strategy.md` for the testing strategy.

## Testing

Test the state seam only. Every feature's logic lives in its selectors, its reducers, and its effects; those are what a spec covers. Components, Firestore services, and end-to-end flows are deliberately not unit-tested.

### What to test

| Seam      | Where it lives                                                | How it is tested                                   |
| --------- | ------------------------------------------------------------- | -------------------------------------------------- |
| Selectors | page-level `*.selectors.ts`, store `extraSelectors`           | `.projector()` with inputs, no store instantiation |
| Reducers  | `<name>.store.ts` via `createFeature`                         | `feature.reducer(state, action)`                   |
| Effects   | `+state/**/*.effects.ts` (functional, `{ functional: true }`) | NgRx TestBed harness                               |

A test asserts external behavior — the actions an effect emits, the state a reducer returns, the value a selector projects — never internal wiring.

### Spec placement and naming

One spec per source file, co-located next to it, named after the source with a `.spec.ts` suffix:

- `+state/<name>.store.ts` → `+state/<name>.store.spec.ts`
- `+state/effects/api.effects.ts` → `+state/effects/api.effects.spec.ts`
- `pages/<page>/<page>.selectors.ts` → `pages/<page>/<page>.selectors.spec.ts`

### Selectors

Selectors are tested purely via `.projector()`, passing the inputs the selector declares and asserting the projected value. No `Store` is instantiated.

```ts
it('provides null initial form values when there is no selected product', () => {
  const viewModel = selectEditProductPageViewModel.projector(null);

  expect(viewModel).toEqual({
    product: null,
    pageTitle: 'Edit product',
    initialFormValues: null,
  });
});
```

### Reducers

Reducers are tested via `feature.reducer(state, action)`. Every store spec opens with a canonical default-state test — feed an unknown action and assert the state is returned unchanged:

```ts
it('returns the initial state for an unknown action', () => {
  const initialState = getInitialState();
  const action = { type: 'Unknown' };

  const state = feature.reducer(initialState, action);

  expect(state).toBe(initialState);
});
```

Follow with one test per reducer case, asserting the state transition.

### Effects

Effects are tested through the NgRx TestBed harness: `provideMockActions` supplies the action stream, `provideMockStore` supplies a `MockStore` with mock selectors (via the `selectors` config or `overrideSelector`), and each data-access dependency is provided as a jest mock. The functional effect is invoked inside `TestBed.runInInjectionContext`, so its `inject()` defaults resolve against the mocked providers. A `Subject<Action>` feeds actions; emitted actions are collected and asserted. See `docs/adr/0004-testing-strategy.md` for the reference implementation.

```ts
TestBed.configureTestingModule({
  providers: [
    provideMockActions(() => actions$),
    provideMockStore({
      selectors: [{ selector: productsFeature.selectCurrentProduct, value: selectedProduct }],
    }),
    { provide: ProductsService, useValue: productsService },
  ],
});
```

### Given / When / Then via blank lines

Test bodies are three paragraphs — arrange (given), act (when), assert (then) — separated by blank lines only. Never use explanatory comments inside a test body.

```ts
it('tracks the selected product', () => {
  const state = productsFeature.reducer(
    getInitialState(),
    EditProductPageComponentActions.selectedProductChanged({
      selectedProduct: 'p1',
    }),
  );

  const selectedProduct = productsFeature.selectSelectedProduct.projector(state);

  expect(selectedProduct).toBe('p1');
});
```

### Coverage is report-only

CI runs the test suite with coverage reporting enabled (`--codeCoverage=true --coverageReporters=text`) so the number is visible in CI output. No coverage threshold is enforced and coverage never blocks a merge.

## E2E smoke tests

E2E tests are a smoke layer, not a coverage layer (see `docs/adr/0005-e2e-smoke-testing.md`). Write one only when a feature touches a Firestore collection or security rule and you need to prove the flow crosses the Firestore boundary — a write that passes rules, resolves a real collection name, and round-trips through a real query. Unit tests cover the logic; smoke tests cover the wiring.

### When to write one

One smoke flow per collection, covering the cross-boundary write/read/delete round-trip (e.g. save -> list -> open -> delete). Never use e2e for selector, reducer, or effect logic.

### Where it lives

`apps/carbotracker-e2e/src/e2e/<flow>.cy.ts`, with reusable steps in `apps/carbotracker-e2e/src/support/`. Tests log in as the seeded development user and self-clean (delete what they create).

### How to run it

```bash
npx firebase emulators:exec 'npx nx e2e carbotracker-e2e' -c apps/carbotracker/firebase.json --import=apps/carbotracker/firebase-data/development
```

E2E is manual only for now; it is not part of CI.
