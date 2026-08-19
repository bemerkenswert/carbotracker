# 0006. Rule-first tickets

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-17

## Context

The saved-meals feature (#172 / PR #195) shipped with its Firestore rules and its feature code in the same PR, and the rules never went live before the code, so the deployed app hit `Missing or insufficient permissions` when saving. Firestore security rules are project-global and deploy only on merge to main — hosting deploys on PR are channel-scoped, but a rules deploy on a PR would push a branch's work-in-progress rules to the production project. Merge-only is therefore the only safe route to production, which means a feature's rules and its code must not land in the same merge if the rules are meant to be live first.

Two facts shape the fix. First, `apps/carbotracker/firestore.rules` opens with a top-level `allow read, write: if false`, so any collection without a match block is already denied — a dedicated deny-by-default block would add visibility, not safety. Second, the thing that deserves review is not "a deny" but the collection's actual access shape, so the rule ticket should carry that shape ready to ship.

## Decision

Feature work for any new Firestore collection is rule-first: a dedicated rules ticket must merge to main before any feature ticket that reads or writes that collection.

- **Scope:** every new collection _path_ — top-level (`products`, `saved-meals`) or subcollection (`current-meals/{id}/products`). The gate is the match block, and a subcollection is its own match block with its own access shape.
- **Content:** the rules ticket ships **ready** — the collection's real owner-pattern rules (e.g. `creator == request.auth.uid`), not a deny placeholder. Deny is already the top-level default.
- **Touching:** applies to any feature ticket that reads _or_ writes the collection, not just writes.
- **Existing collections:** relaxing an existing collection (granting a new access shape) follows the same gate — a rules ticket first. Tightening an existing collection (removing/restricting access) needs no ordering gate.
- **Ordering:** enforced via native blocker links — the feature ticket is `blocked_by` the rules ticket.
- **Review:** a PR that modifies `firestore.rules` must carry a `security-rule-approved` label before it can merge, enforced by a new `rules-gate` job in `merge-gate.yml`. Every rules diff reaches production on merge, so every one needs human sign-off, regardless of ticket ordering.

## Consequences

- `docs/agents/issue-tracker.md` gains a "Rule-first tickets" convention section describing the how.
- `.github/workflows/merge-gate.yml` gains a `rules-gate` job mirroring the existing fail-closed label gate.
- The `security-rule-approved` label is created and applied by a human (like `human-approved`), never by an agent.
- Rule tickets and feature tickets touching the same collection now carry a `blocked_by` edge in the tracker.
