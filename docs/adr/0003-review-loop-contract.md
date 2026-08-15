# 0003. Review-loop contract

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-15

## Context

The orchestrator's review loop (`orchestrator_review_round`) resumes the original opencode session headlessly with `/review-comments`. That skill's "Discuss with the dev" step asks a question that headless mode has no channel to answer, then the run exits `0` anyway. The orchestrator trusts exit `0`, advances the watermark, and silently drops the thread — a comment that needs human judgment is never answered and never re-triggers. Live repro: issue #245 → PR #246, a repo-wide "ngrx→ngxs" question that went unanswered.

Two coupled defects: (a) the skill asks a question headless mode can't answer, and (b) the orchestrator trusts the exit code alone and never checks that a reply actually happened.

## Decision

Split review handling into an **analyze** phase (headless opencode, emits a plan file) and an **act** phase (bash, applies the plan). Make `review-comments` mode-aware.

### Mode-aware skill

`review-comments` gains a **Headless mode**, passed explicitly by the caller (opencode exposes no clean non-interactive signal — the orchestrator appends _"headless: do not ask, do not post, do not implement — write the plan file"_). In headless mode the skill never asks, never posts, never implements; it classifies and writes the plan. Interactive users keep today's ask-questions flow. One skill, two modes.

### Analyze/act split

- **Analyze**: `opencode run --auto --session <id>` invoking headless `/review-comments`, which writes a structured plan to `ORCHESTRATOR_REVIEW_PLAN_FILE` (JSON).
- **Act** (bash): read the plan and apply it per comment.

### Plan schema

Machine-checkable contract: `.agents/skills/review-comments/review-plan.schema.json` (validated by `tools/tests/ct-review-plan.test.sh`). Shape:

```json
{ "needsHuman": false, "comments": [{ "commentId": 3788850731, "path": "README.md", "line": 4, "type": "answer", "reply": "…", "confidence": 0.9 }] }
```

### Comment types

| type      | meaning                           | action                                                          | resolve thread? | needsHuman |
| --------- | --------------------------------- | --------------------------------------------------------------- | --------------- | ---------- |
| answer    | supply requested info             | post reply (footer)                                             | no              | no         |
| pushback  | reasoned disagreement w/ reviewer | post reply (footer)                                             | no              | yes        |
| question  | clarify with the reviewer         | post reply (footer)                                             | no              | yes        |
| implement | make the change                   | resume session → `/implement` → commit → push → reply → resolve | yes             | no         |

Bash never needs the GraphQL resolve logic — resolution only happens on `implement`, which stays inside opencode (the skill already documents the `resolveReviewThread` mutation).

### Confidence gate

A comment is only classified `implement` at confidence ≥ `0.8`. Below that it is downgraded to `question` (reply but don't implement) and sets `needsHuman`. Escalation to `needs-triage` is reserved for pipeline failures, not low-confidence comments.

### needsHuman

When `needsHuman` is set, the orchestrator **advances the watermark and pauses polling** for that PR (posting a maintainer notice), so the comment is neither re-triggered forever nor silently consumed.

> **Interim, until #250 lands:** the act phase only implements reply actions. An `implement`-type comment (schema-legal, `needsHuman` false) is currently handled like `needsHuman` — its plan reply is posted, polling pauses, and a maintainer notice goes out — so it is never silently consumed. #250 replaces this with the real implement step.

### Commit granularity

One commit per `implement` comment, so each thread's reply cites a specific commit.

### Watermark

`lastCommentAt` advances only after the **act** phase applies the plan. Analyze failure / empty plan / malformed JSON falls through to the existing retry/escalate semantics.

## Considered options

- **Plan channel**: file vs stdout-JSON vs `opencode run --format json`. Chose **file** — the orchestrator already keeps stdout clean (helpers return values there, logs go to stderr), and a file is trivially fake-able in `npm run test:tools`.
- **Implement step**: reuse `/implement` with a comment-scoped prompt vs a new `implement-review-comment` skill. Chose **reuse** — `review-comments` already delegates to `/implement` for its agree set, and the skill is deliberately thin.
- **`answer` vs `pushback`**: keep distinct vs merge. Chose **distinct** — `pushback` is the agent arguing with a human and warrants `needsHuman` sign-off; `answer` is low-stakes and does not.

## Consequences

- `review-comments` gains a headless section; the interactive flow is unchanged.
- `orchestrator_review_round` splits into analyze + act; the watermark only moves on a successful act.
- `needsHuman` introduces a paused-polling state distinct from the retry-exhaustion pause.
- Bash tests cover the plan-file contract (`tools/tests/ct-review-plan.test.sh`, validating against the JSON Schema), and the orchestrator tests (`tools/tests/ct-orchestrator.test.sh`) cover the type→action mapping and the watermark/pause behavior.
