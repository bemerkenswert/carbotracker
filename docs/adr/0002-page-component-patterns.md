# 0002. Page component patterns

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-10

## Context

Pages in the codebase have diverged into two patterns — older pages embed guard logic, form sync, and payload construction inside the component class, while newer pages (CurrentMealPage, SavedMealsPage) follow a pure `selectSignal` + `dispatch` pattern. We need a single convention so every page is uniformly testable at the selector seam.

A second ambiguity: the codebase uses both template-driven forms (`FormsModule`) and reactive forms (`ReactiveFormsModule`), sometimes in the same page. This inconsistency makes validation logic ad-hoc and prevents consistent page architecture.

## Decision

### Two page archetypes

| | Display page | Form page |
|---|---|---|
| **Reads** | `selectSignal(selectViewModel)` only | `selectSignal(selectViewModel)` + `FormGroup` |
| **Writes** | `dispatch(action())` | `dispatch(action(formGroup.value))` |
| **Sync** | None | `effect()` patches `formGroup` from `viewModel()` |
| **Validation** | N/A | Declarative validators on `FormControl` |
| **Example** | CurrentMealPage, SavedMealsPage | EditProductPage, login-page |

Every page gets a page-level `*.selectors.ts` file with a `select<Page>ViewModel` selector. Display-page viewModels compose derived display values. Form-page viewModels provide `initialFormValues` (to prime the form from store state), `pageTitle`, and any toolbar/chrome derived values. Create pages with nothing to prime from store expose their (static) initial values and page title through the viewModel so the component reads state only through the selector seam.

### Form approach: reactive forms

All form pages use `ReactiveFormsModule` with a `FormGroup`. Validators are declared on `FormControl` — not guarded imperatively in the component. The component never checks `formGroup.valid` before dispatching; the template uses `[disabled]="formGroup.invalid"` on the submit button (plus `pristine` where saving an unchanged edit form is meaningless).

### Event-driven action chain

Every user interaction flows through a strict chain:

```
Component dispatch → Effect (API call) → API Success/Failure action → Routing/Snackbar effects
```

Routing effects always listen to the **API success action** (`...Successful`), never the component action. This keeps the chain direct and avoids routing before the write completes. Snackbar effects show success or error messages on the corresponding API outcome.

### No loading spinners, no blocked save buttons

The app uses Firebase Firestore with real-time listeners. A local write hits the IndexedDB cache, triggers the listener, and pushes updated state into NgRx in the same event loop tick — so there is zero visible latency between saving and seeing the result. The UI does not show spinners or disable save buttons during writes. Errors surface reactively via snackbar on the `...Failed` actions.

## Considered options

### Template-driven vs reactive vs signal forms

- **Template-driven forms** — already used in product/meal-entry pages. Would keep imperative guards in the component (the exact problem this refactor targets).
- **Reactive forms** — already established in auth/settings pages. Validators are declarative and testable. Eliminates imperative `if (this.model.x)` guards from components.
- **Signal forms** — Angular's newest API. Not yet adopted in the codebase. Would require team ramp-up and offers no advantage over reactive forms for this app's form complexity.

Reactive forms chosen because they (a) already have adoption in the codebase, (b) directly eliminate the component logic targeted by this refactor, and (c) are battle-tested across all supported Angular versions.

### Merge logic location (EditProductPage)

For editing an existing entity, the save payload must merge the existing store entity with the form delta. Options:
- **Component** merges before dispatching — requires the component to read store state.
- **Selector** derives the merge — requires passing form values through the selector chain.
- **Effect** reads the existing entity from store via `concatLatestFrom` and merges — component dispatches only the form delta.

Effect merge chosen: keeps the component thinnest, and the merge belongs to the data layer.

## Consequences

- Product, meal-entry, and other older form pages migrate to `ReactiveFormsModule` + `FormGroup`.
- Three pages in scope for immediate refactor: CreateProductPage, EditProductPage, CreateMealEntryPage.
- EditMealEntryPage and SavedMealNameDialog remain as follow-up work (same pattern, different ticket).
- `CreateMealEntryPage` routing effect changes from listening to `saveClicked` to `addMealEntrySuccessful` — aligning with the event-driven chain.
- `EditProductPageComponentActions.saveProductClicked` drops the `exisitingProduct` prop — the effect derives it.
- `CreateMealEntryPageComponentActions.saveClicked` changes from `{ mealEntry }` to `{ product, amount }` — the effect constructs the MealEntry.
