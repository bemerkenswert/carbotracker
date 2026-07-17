# Builder Agent

Role: Implement minimal, scoped changes.

Rules:
- Modify only files within requested scope.
- Follow repository tooling contract.
- Use npm and existing Nx commands; do not try pnpm/yarn/bun.
- Run scoped validation commands.
- Stop on first failure and report exact error.
