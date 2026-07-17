# Copilot Instructions — bemerkenswert/carbotracker

## Operating mode
- Plan first (max 5 bullets), then execute.
- Keep changes minimal and task-focused.
- Do not perform unrelated refactors.

## Tooling contract (authoritative)
- Package manager is **pnpm**.
- Do **not** use npm, yarn, or bun.
- Install dependencies with:
  - `corepack enable`
  - `pnpm install --frozen-lockfile`

## Validation contract
- Run only the minimum required validation for changed scope.
- Prefer scoped workspace commands (`pnpm --filter ...`).
- If formatting/lint/test command is unknown, read package scripts first.
- Do not run repo-wide expensive checks unless explicitly requested.

## Monorepo rules
- Identify target workspace before editing.
- Modify only files in target workspace unless task explicitly requires cross-workspace changes.
- If task is ambiguous about workspace, stop and ask.

## Failure handling
- If install or validation fails, stop immediately.
- Report exact failing command + first relevant error lines.
- Propose the smallest possible fix.

## Output format (always)
1) Plan
2) Files changed
3) Commands run
4) Validation results
5) Risks / follow-ups
