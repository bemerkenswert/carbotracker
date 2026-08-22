# 0007. Best practices

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-22

## Context

Review rounds on the sport dialog (#349 / PR #360) surfaced recurring conventions worth recording so future forms follow them without another round-trip. The rules live here as the reference the review loop enforces.

## Decision

### Bind reactive form controls with `[formControl]`, not `formControlName`

Bind every reactive form control to the template with the `[formControl]="formGroup.controls.x"` property binding, never the `formControlName="x"` string directive.

`formControlName` resolves a string key against a parent `formGroup` directive at runtime. A typo in the name fails silently, and a control without the parent `formGroup` directive throws `NG01050` (`formControlName must be used with a parent formGroup`), which is how the Save button ended up permanently disabled in an earlier round of the sport dialog. `[formControl]` binds the actual `FormControl` instance directly, so a typo in `formGroup.controls.x` is a compile-time TypeScript error, and the binding needs no parent `formGroup` wrapper at all.

### Use the default `mat-form-field` appearance

Do not set the `appearance` attribute on `mat-form-field`. The default appearance is already `fill` (Angular Material `DEFAULT_APPEARANCE = 'fill'`), so `appearance="fill"` is a redundant no-op that only invites drift from the default.

### Declare required validation on the FormControl, not the template

Do not put the `required` attribute on an input bound to a reactive form control. Declare `Validators.required` on the `FormControl` instead.

`MatInput.required` derives from the bound control via `hasValidator(Validators.required)`, so the Material required marker still renders when the control carries `Validators.required`. A template `required` attribute is a second source of truth that duplicates — and can silently disagree with — the control's validation.

## Consequences

- Templates bind controls via `[formControl]` and omit the `[formGroup]` wrapper, the `appearance` attribute on `mat-form-field`, and the `required` attribute on inputs whose control already declares `Validators.required`.
- The sport dialog aligns with ADR-0002's `[formControl]` recommendation; older dialogs that still use `formControlName` are accepted legacy.
