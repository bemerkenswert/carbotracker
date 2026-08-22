# 0007. Parallel orchestrator sessions

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-21

## Context

The orchestrator daemon (`tools/ct-orchestrator.sh`) runs its pipeline fully serially: `orchestrator_implement` blocks on `opencode run`, and `orchestrator_review_round` blocks on `opencode run --session … /review-comments`, so at most one `opencode` session executes at a time. `ORCHESTRATOR_CONCURRENCY_CAP` therefore only bounded how many tickets the daemon *claimed per poll cycle*, not how many sessions were genuinely *doing work*. Issue #239 asks for several tickets to make progress at once (one implementing, another having its review comments acted on) without exhausting the VPS.

A deeper constraint surfaced during grilling: the existing `reconcile` (run at the top of every poll) relied on the invariant that "all implement and review work is synchronous within a poll, so no entry is ever mid-flight when a poll-boundary reconcile observes it." Any parallelism shatters that invariant, so the design must replace it with explicit per-entry liveness rather than assume quiescence at a poll boundary.

## Decision

The daemon launches each `opencode` session — an implement run or a `/review-comments` round — as a **background child of the daemon process**, tracked by process id, and reaps finished children to free their slot.

- **Single shared cap.** One cap bounds *all* running sessions; implement runs and review rounds draw from the same budget. The merge poll's git operations are explicitly *not* active sessions and stay uncapped.
- **Config rename.** The cap becomes `ORCHESTRATOR_ACTIVE_SESSION_CAP`. The previous name is honoured through a deprecation shim (read if the new name is unset) and a warning is logged when the deprecated name is the effective source.
- **Liveness via process id, not phase.** Each state entry gains a `pid` field. The active count counts entries whose `pid` is set *and* whose process is alive in the daemon's process group (`kill -0`). The state file's load→modify→write cycle is serialised with an external lock so parallel jobs cannot clobber each other.
- **Self-contained child jobs.** All per-ticket logic (worktree, dependency install, the `opencode` run, the stalled/empty/opencode-failure classification, retry/escalate) runs *inside* the background job. The reaper reads the child's exit status; if the child already finalised its entry, the reaper only clears the `pid` and frees the slot. Failure handling stays per-ticket and isolated by the state lock.
- **Self-refresh deferral.** The daemon's re-exec-on-script-change is deferred until no session is in flight, so background children are not orphaned by a re-exec.
- **Watchdog.** An optional `ORCHESTRATOR_SESSION_TIMEOUT_SECONDS` (default off / very large) bounds a single session's runtime; exceeding it terminates the session (`SIGTERM` then `SIGKILL`) and routes the entry to the existing retry/escalate path.
- **Crash recovery unchanged in source of truth.** Stored `pid`s are authoritative only for the daemon instance that wrote them. On startup all `pid` fields are cleared and `reconcile` re-derives each ticket from observable git facts (pushed branch, open PR, unpushed work) exactly as before.

The unit the cap counts is an **active session**: a running `opencode` invocation (implement or review round). This is distinct from a *claimed/idle ticket* — a ticket in the pipeline whose session is not currently running. The term is recorded in `CONTEXT.md`.

## Considered options

- **Detached `setsid`/`nohup` process per ticket, polled for liveness by pid.** Survives a full daemon restart without orphaning, but reaping/zombie handling and "is this pid really mine" tracking get messier, and it splits ownership of the session between the daemon and an independent process. Rejected in favour of background children owned by the daemon's process group.
- **Worker subprocess model (`xargs -P` / a dedicated runner script per ticket).** Simpler parallelism but loses the tight in-loop control and the self-refresh semantics the daemon already assumes. Rejected.
- **Derive liveness purely from git facts at poll time (no `pid` field).** Cannot observe a *running* `opencode` process from git — git only shows results (commits appeared or not), so a run that has been chewing for 20 minutes is indistinguishable from one that died instantly. This either over-counts (treats every `implementing` entry as a slot) or under-detects orphans, reintroducing the very over-counting the cap exists to prevent. Rejected; `pid` + `kill -0` is the only approach giving a real-time, accurate count, with git-fact `reconcile` kept as the cross-restart backstop.
- **Separate implement and review caps.** More knobs, more config surface, and review rounds are cheap relative to implement, so the extra dial rarely earns its keep. Rejected; one shared cap bounds the only real resource (model/VPS load).
- **Keep the old `ORCHESTRATOR_CONCURRENCY_CAP` name, rebind semantics.** The name actively misleads (it reads as a per-poll claim bound). Rejected in favour of a self-documenting rename with a one-release shim.

## Consequences

- `CONTEXT.md` gains an "Active session" / "Claimed/idle ticket" glossary pair.
- `tools/ct-orchestrator.sh`: background-launch + reaper, `pid` field, `flock`-guarded state writes, `kill -0` active count, self-refresh deferral, watchdog. The `merge poll` stays outside the cap.
- `tools/ct-orchestrator.conf`, setup/verify scripts, and docs move to `ORCHESTRATOR_ACTIVE_SESSION_CAP` with the deprecation shim.
- `reconcile`'s "nothing mid-flight at a poll boundary" assumption is retired and replaced by per-entry `pid` liveness plus the git-fact backstop — the key risk this ADR retires.
- `tools/tests/ct-orchestrator.test.sh` gains cases (via `fake_command` stubs for `opencode`/`wait`/`kill`) asserting cap enforcement, slot freeing on child exit, idle `awaiting review` not counted, review rounds consuming the cap, stored `pid`s ignored after a simulated restart, watchdog termination, and self-refresh deferral.
