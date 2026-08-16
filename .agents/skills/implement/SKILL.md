---
name: implement
description: 'Implement a piece of work based on a spec or set of tickets.'
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work.

Commit your work to the current branch.

<!-- BEGIN carbotracker-local: keep this block intact when merging upstream skill updates -->

## Missing dependencies

**Never install anything.** This skill never installs system software: no
`apt`/`apt-get`/`snap`/`dpkg`, no `sudo`, no downloading or extracting
binaries to work around a missing tool, and no `npm install -g`. Adding a
project dependency through `package.json` (and `npm ci`, which the
orchestrator already runs before the session) is a normal code change and
stays allowed.

When a command this work needs is not on PATH (e.g. `java` for the Firebase
emulators, `Xvfb`/`xkbcomp` for Cypress headless runs), **stop immediately** —
never attempt to install or work around it.

- **Interactive**: report the missing tool(s) to the user and stop.
- **Headless**: the caller sets `ORCHESTRATOR_IMPLEMENT_ABORT_FILE` and says
  so in the prompt ("headless: do not ask, do not install — write the abort
  file"). Write the abort artifact to that file (fail loudly if unset) and
  exit non-zero, never asking and never installing. The machine-checkable
  contract is `implement-abort.schema.json` next to this skill; the artifact
  must validate against it. Shape:

  ```json
  { "type": "missing-dependency", "dependencies": ["java"], "reason": "The Firebase emulators need a Java runtime." }
  ```

  - `type` is `missing-dependency` — the one abort type the orchestrator
    dispatches on: it skips the retry and escalates to a human.
  - `dependencies` lists the missing tools (command names, non-empty).
  - `reason` is one line on why the tool is required.

<!-- END carbotracker-local -->
