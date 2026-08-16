# 0005. Implement abort contract

- **Status:** Accepted
- **Deciders:** carbotracker maintainers
- **Date:** 2026-08-16

## Context

The orchestrator runs `/implement` headlessly (`opencode run --auto`) for every
ticket. When a required tool is missing on the host, the agent works around it:
it downloads debs (`apt-get download`), extracts them into `/tmp`, assembles
`LD_LIBRARY_PATH`/`XKB_BINDIR` chains, and burns the run budget — 51 minutes of
CPU for issue #187 before the run was killed. The orchestrator then retries the
run with `--continue`, which cannot fix a missing system tool, and the eventual
escalation tells the human nothing about what is actually missing.

Two coupled defects: (a) the agent treats a missing dependency as a solvable
problem and tries to install it, and (b) the orchestrator has no typed failure
channel — it only sees exit non-zero, so it retries and escalates generically.

## Decision

`/implement` never installs anything, and a headless run that cannot proceed
reports a **typed abort** through a structured artifact, mirroring the
review-loop contract (ADR-0003): the agent resolves the failure to a type, the
orchestrator validates and dispatches on it.

### Never install

The implement skill forbids installing system software: no
`apt`/`apt-get`/`snap`/`dpkg`, no `sudo`, no downloading or extracting binaries
to work around a missing tool, and no `npm install -g`. Adding a project
dependency through `package.json` (and `npm ci`, which the orchestrator runs
before the session) is a normal code change and stays allowed.

### Typed abort

A headless run is told so explicitly in the prompt and gets the abort-file path
via `ORCHESTRATOR_IMPLEMENT_ABORT_FILE`. When it cannot proceed because a tool
is missing, it writes the artifact and exits non-zero — never asking, never
installing. Machine-checkable contract:
`.agents/skills/implement/implement-abort.schema.json` (validated by
`tools/tests/ct-implement-abort.test.sh`). Shape:

```json
{ "type": "missing-dependency", "dependencies": ["java"], "reason": "The Firebase emulators need a Java runtime." }
```

### Orchestrator dispatch

`orchestrator_run_opencode` gives every attempt its own abort file. On failure
it validates the artifact against the schema:

- `missing-dependency` → **no `--continue` retry** (retrying cannot fix a
  missing system tool), immediate escalation to `needs-triage` with a comment
  naming the missing tools and telling the maintainer to install them on the
  host and re-tag the ticket. The poll loop sees a new failure kind
  (`missing-dependency`) so it stays off the generic bounded-retry path.
- absent, malformed, or schema-invalid artifact → the existing generic
  retry/escalate path, unchanged. Exit code alone is never the dispatch
  signal.

The resume path (`orchestrator_resume_implementation`, used by crash
recovery) applies the same contract.

## Considered options

- **Abort channel**: file vs stdout-JSON vs `opencode run --format json`.
  Chose **file** — same reasoning as ADR-0003: the orchestrator keeps stdout
  clean, and a file is trivially fake-able in `npm run test:tools`.
- **Fail fast at claim time**: check the host's tools in the daemon before
  launching the agent. Rejected — java/Xvfb are only needed by some tickets
  (emulator/e2e work); a blanket gate would block every ticket. The host
  check lives in `ct-orchestrator-verify.sh` (`verify_prereq_tools`), run by
  a human, and the per-ticket abort is the runtime guard.
- **New skill**: a dedicated `implement-abort` skill vs. extending
  `/implement`. Chose **extend** — the missing-dependency stop happens inside
  the implement flow itself, and the skill is deliberately thin.

## Consequences

- `implement` gains a headless abort section; the interactive flow only gains
  the never-install rule.
- `orchestrator_run_opencode` returns three codes (0 success, 1 generic
  failure, 3 typed abort), the implement/resume callers dispatch on the code,
  and the missing-dependency payload (the tool list) travels in
  `CT_RUN_ABORT_DEPENDENCIES`.
- Host prerequisites (java, Xvfb, xkbcomp) are required by
  `tools/ct-orchestrator-setup.sh` (on PATH) and asserted at their `/usr/bin`
  locations by `tools/ct-orchestrator-verify.sh` (`verify_prereq_tools`) —
  the latter is the precise check, since Xvfb spawns xkbcomp at a compiled-in
  absolute path.
- Bash tests cover the contract: schema validation
  (`tools/tests/ct-implement-abort.test.sh`) and the no-retry escalation path
  plus the unchanged fallback (`tools/tests/ct-orchestrator.test.sh`).
