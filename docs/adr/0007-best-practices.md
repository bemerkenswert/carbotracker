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

## Consequences

- Templates bind controls via `[formControl]` and omit the `[formGroup]` wrapper.
- The sport dialog aligns with ADR-0002's `[formControl]` recommendation; older dialogs that still use `formControlName` are accepted legacy.
