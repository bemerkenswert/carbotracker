# 0004. Testing strategy

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-16

## Context

Carbotracker's tests accumulated before anyone decided what should be tested or how. Specs were added ad-hoc: two effect-test styles coexisted (a hand-rolled mock store plus direct calls to exported effect functions, and one TestBed-based service spec), component and service coverage was absent, and a reviewer's "Standards" pass had no concrete file to enforce. A maintainer or agent could not tell (a) which seams deserve tests, (b) where a spec belongs and how it is named, (c) which effect-test technique to use, or (d) what CI does with coverage. The feature logic lives in the state seam — selectors, reducers, and effects — because pages are thin (`selectSignal` + `dispatch`, per ADR-0002) and services are thin Firestore wrappers. The tests should land where the logic is.

## Decision

Test the state seam only: selectors, reducers, and effects. Component, service, and end-to-end tests are out of scope. Rules are recorded in the repo-root `CODING_STANDARDS.md`; this ADR records the decision and its trade-offs.

### Selectors

Tested purely via `.projector()` with the selector's declared inputs; no `Store` is instantiated.

### Reducers

Tested via `feature.reducer(state, action)`. Every store spec opens with a canonical default-state test asserting an unknown action returns the initial state unchanged, then one test per reducer case.

### Effects

Effects are tested through the NgRx TestBed harness. The action stream comes from `provideMockActions`, store state from `provideMockStore`/`MockStore` with mock selectors (the `selectors` config or `overrideSelector`), and each data-access dependency is provided as a jest mock. The functional effect is invoked inside `TestBed.runInInjectionContext` so its `inject()` defaults resolve against the mocked providers. A `Subject<Action>` feeds actions; emitted actions are collected and asserted. This replaces the previous hand-rolled `{ select: jest.fn() }` mock store and direct-call style.

### Spec placement, structure, coverage

One spec per source file, co-located, named `<source>.spec.ts`. Test bodies follow Given / When / Then separated by blank lines only — never explanatory comments. Coverage is reported in CI but never gated.

### Reference implementation

The harness for `updateProduct$` (`features/products/+state/effects/api.effects.ts`):

```ts
import { TestBed } from '@angular/core/testing';
import { Action } from '@ngrx/store';
import { provideMockActions } from '@ngrx/effects/testing';
import { MockStore, provideMockStore } from '@ngrx/store/testing';
import { of, Subject, throwError } from 'rxjs';
import { ProductsService } from '../../services/products.service';
import { ProductsApiActions } from '../actions/api.actions';
import { EditProductPageComponentActions } from '../actions/component.actions';
import { productsFeature } from '../products.store';
import { updateProduct$ } from './api.effects';

const selectedProduct = {
  id: 'p1',
  name: 'spaghetti',
  creator: 'user-a',
  carbs: 25,
};

describe('updateProduct$', () => {
  let actions$: Subject<Action>;
  let store: MockStore;
  let productsService: jest.Mocked<ProductsService>;

  beforeEach(() => {
    actions$ = new Subject<Action>();
    productsService = {
      updateProduct: jest.fn(() => of(undefined)),
    } as unknown as jest.Mocked<ProductsService>;

    TestBed.configureTestingModule({
      providers: [
        provideMockActions(() => actions$),
        provideMockStore({
          selectors: [
            {
              selector: productsFeature.selectCurrentProduct,
              value: selectedProduct,
            },
          ],
        }),
        { provide: ProductsService, useValue: productsService },
      ],
    });

    store = TestBed.inject(MockStore);
  });

  it('merges the existing product with the changed product and updates it', () => {
    const results: Action[] = [];

    TestBed.runInInjectionContext(() => updateProduct$().subscribe((action) => results.push(action)));

    actions$.next(
      EditProductPageComponentActions.saveProductClicked({
        changedProduct: { name: 'rigatoni', carbs: 30 },
      }),
    );

    expect(productsService.updateProduct).toHaveBeenCalledWith({
      ...selectedProduct,
      ...{ name: 'rigatoni', carbs: 30 },
    });
    expect(results).toEqual([ProductsApiActions.updatingProductSuccessful()]);
  });

  it('dispatches updatingProductFailed when the update fails', () => {
    productsService.updateProduct.mockReturnValue(throwError(() => new Error('boom')));
    const results: Action[] = [];

    TestBed.runInInjectionContext(() => updateProduct$().subscribe((action) => results.push(action)));

    actions$.next(
      EditProductPageComponentActions.saveProductClicked({
        changedProduct: { name: 'rigatoni', carbs: 30 },
      }),
    );

    expect(results).toEqual([
      ProductsApiActions.updatingProductFailed({
        error: expect.any(Error),
      }),
    ]);
  });

  it('does nothing when there is no selected product', () => {
    store.overrideSelector(productsFeature.selectCurrentProduct, null);
    const results: Action[] = [];

    TestBed.runInInjectionContext(() => updateProduct$().subscribe((action) => results.push(action)));

    actions$.next(
      EditProductPageComponentActions.saveProductClicked({
        changedProduct: { name: 'rigatoni', carbs: 30 },
      }),
    );

    expect(productsService.updateProduct).not.toHaveBeenCalled();
    expect(results).toEqual([]);
  });
});
```

## Considered options

### The seam: components vs services vs end-to-end vs the state seam

- **Component harness** (CDK component harness / `TestBed.createComponent`): pages are deliberately thin (`selectSignal` + `dispatch`, ADR-0002); the logic they would exercise lives in the selectors and effects below them. Component tests couple to the DOM and rendering, which this app's state logic does not need, and they are slower and more brittle.
- **Service tests** (unit-testing the Firestore service wrappers): the services are thin wrappers over Firestore listeners and writes; unit-testing them means mocking Firestore to exercise little more than the mock. Their behavior surfaces through the effect tests that call them.
- **End-to-end** (Cypress): the slowest and flakiest layer, with no meaningful coverage of the state logic; reserved for smoke flows, not the coverage strategy.
- **State seam** (selectors, reducers, effects): chosen. All behavior worth pinning down is expressible as a projected value, a state transition, or an emitted action — fast, deterministic, and independent of the DOM and of Firestore.

### Effect technique: TestBed harness vs direct-call effects

- **Direct-call effects**: the pre-decision style — call the exported functional effect with a raw `Subject` and a hand-rolled `{ select: jest.fn() }` store. Rejected: it bypasses Angular DI, duplicates what NgRx already provides, couples every spec to the effect's default-parameter ordering, and never exercises the real `Actions` or `Store` providers, so a spec can pass against wiring that breaks in the app.
- **NgRx TestBed harness** (`provideMockActions` + `provideMockStore`/`MockStore`, invoked via `TestBed.runInInjectionContext`): chosen. It provides the real `Actions` and `Store` tokens, mocks only what the effect injects, and keeps the effect's `inject()` defaults intact so the spec mirrors how the effect is wired in the app.

## Consequences

- `CODING_STANDARDS.md` gains a Testing section; it becomes the Standards reference the review loop enforces.
- Existing effect specs migrate from the direct-call style to the TestBed harness, one per-feature migration ticket at a time (products, current-meal, settings, saved-meals); new effect specs are written to the harness from now on.
- The probationary saved-meals specs are reworked on that feature's migration ticket rather than here.
- Coverage stays report-only in CI; no threshold is added.
