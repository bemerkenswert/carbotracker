# Carbotracker orchestrator

`ct-orchestrator.sh` is the ticket-to-PR pipeline: it polls GitHub for
`ready-for-agent` tickets, claims them up to a concurrency cap, and runs each
one through a full implementation cycle — worktree, dependency install,
headless `opencode`, and finally a pushed branch with a pull request. Once a
PR is up it also runs the **review loop**: every poll it checks awaiting-review
PRs for new comments and, when it finds one, resumes the original opencode
session with `/review-comments` so the agent answers the review and pushes
updates. It runs as a systemd user service (see
`carbotracker-orchestrator.service`).

## Lifecycle

A ticket moves through phases as the orchestrator works it:

```mermaid
stateDiagram-v2
    [*] --> implementing: poll finds eligible ticket, claim flips GitHub labels
    implementing --> awaiting_review: opencode done, PR opened
    implementing --> [*]: failure, un-claim and clean up
    awaiting_review --> review_round: new comment on PR (newer than lastCommentAt)
    review_round --> awaiting_review: /review-comments succeeds or a retry fails
    awaiting_review --> [*]: human merges the PR
```

`implementing` means the orchestrator is actively running a session for the
ticket; `awaiting review` means the PR exists and a human should look at it.
Only `implementing` entries count against the concurrency cap.

A claim is recorded **twice**: on the GitHub issue (remove `ready-for-agent`,
add `in-progress`) and in the local state file. The label flip is what makes
the claim visible to humans and atomic against parallel orchestrators — once
an issue drops `ready-for-agent` it stops matching the candidate query, so a
second daemon cannot claim it.

## Review loop

Each poll, after claiming work, the orchestrator walks every state entry in
`awaiting review` that has a PR number and a session id:

- It queries the PR's review surfaces — inline threads
  (`pulls/<n>/comments`) and general comments (`issues/<n>/comments`) — and
  takes the newest `created_at` across both as the latest comment timestamp.
- If that timestamp is newer than the entry's `lastCommentAt`, it launches
  `opencode run --auto --session <sessionId> "/review-comments on PR #<n>"`
  in the worktree — the same session that implemented the ticket, so the
  agent keeps full context.
- On success the watermark advances to the newest comment (which includes the
  agent's own replies, so the round never re-triggers on itself) and the
  failure counter resets.
- On failure the orchestrator logs the error, increments `reviewFailures`,
  and posts a visible notice on the PR — "Automated review round failed
  (attempt N/R)". The watermark stays put, so the same round is retried on
  the next poll (self-healing).
- After `ORCHESTRATOR_REVIEW_RETRIES` consecutive failures the watermark is
  advanced anyway and polling pauses: the PR stays stale until a human
  intervenes. A newer human comment on the PR starts a fresh retry budget.

## State file

Active tickets live in a single JSON array, written atomically
(temp file + rename). Default location:
`$HOME/.local/state/carbotracker/orchestrator.json`.

```json
[
  {
    "ticket": 218,
    "branch": "ticket/218-worktree-creation-opencode-implementation-and-pr-tracking",
    "worktree": "/home/steffen/git/worktrees/carbotracker/218-worktree-creation-opencode-implementation-and-pr-tracking",
    "sessionId": "ses_007927ec0ffeYJFyKLBlmBSp1e",
    "prNumber": 234,
    "lastCommentAt": "2026-08-13T00:07:00Z",
    "reviewFailures": 0,
    "phase": "awaiting review",
    "startedAt": "2026-08-13T00:07:00Z"
  }
]
```

| Field            | Meaning                                                     |
| ---------------- | ----------------------------------------------------------- |
| `ticket`         | GitHub issue number being implemented                       |
| `branch`         | `ticket/<issue>-<slug>` branch the work happens on          |
| `worktree`       | Absolute path of the git worktree for that branch           |
| `sessionId`      | opencode session id for the run (`null` until it exits)     |
| `prNumber`       | PR opened for the branch (`null` until it exists)           |
| `lastCommentAt`  | Newest comment timestamp handled on the PR (`null` = never) |
| `reviewFailures` | Consecutive failed review rounds (resets on success)        |
| `phase`          | `implementing` or `awaiting review`                         |
| `startedAt`      | UTC timestamp of the claim                                  |

## Data flow per poll

```mermaid
flowchart TD
    A[gh issue list ready-for-agent,ticket] --> B{unblocked? skip already-claimed / blocked / at cap}
    B -- eligible --> C[claim: remove ready-for-agent, add in-progress + append state entry]
    C --> D[ct_worktree_add: git fetch origin/main + worktree add -b ticket/N-slug]
    D --> E[npm ci --prefer-offline --no-audit --no-fund]
    E --> F[opencode run --auto --title carbotracker-ticket-N /implement the issue is N]
    F --> G[opencode session list → sessionId by title]
    G --> H[git push -u origin branch]
    H --> I{PR exists?}
    I -- no --> J[gh pr create --base main --head branch]
    I -- yes --> K
    J --> K[gh pr list --head branch → prNumber]
    K --> L[state: sessionId + prNumber, phase awaiting review]
    L --> M[gh issue comment: Started implementation. PR #N created.]
    F -- failure --> N[un-claim + remove worktree/branch, retry next poll]
    M --> O[review loop: walk awaiting-review entries]
    O --> P[gh api pulls/N/comments + issues/N/comments → newest created_at]
    P --> Q{newer than lastCommentAt?}
    Q -- no --> O
    Q -- yes --> R[opencode run --auto --session S /review-comments on PR #N]
    R -- success --> S[watermark = newest comment, failures = 0]
    R -- failure --> T[failures++, post PR notice attempt N/R]
    T -- failures < R --> O
    T -- failures = R --> U[watermark advanced, polling pauses for human]
```

The orchestrator never resolves review threads or merges — after the PR is
opened it hands off to a human.

## Configuration

Sourced from `ct-orchestrator.conf` (environment variables win over the conf
file, which wins over defaults):

| Variable                             | Default                                             |
| ------------------------------------ | --------------------------------------------------- |
| `ORCHESTRATOR_POLL_INTERVAL_SECONDS` | `300`                                               |
| `ORCHESTRATOR_CONCURRENCY_CAP`       | `3`                                                 |
| `ORCHESTRATOR_ISSUE_LABELS`          | `ready-for-agent,ticket`                            |
| `ORCHESTRATOR_IN_PROGRESS_LABEL`     | `in-progress`                                       |
| `ORCHESTRATOR_REVIEW_RETRIES`        | `3`                                                 |
| `ORCHESTRATOR_STATE_FILE`            | `$HOME/.local/state/carbotracker/orchestrator.json` |
| `ORCHESTRATOR_WORKTREE_PARENT`       | `$HOME/git/worktrees/carbotracker`                  |

## Running

- `ct-orchestrator.sh` — run the daemon (systemd user service).
- `ct-orchestrator.sh once` — run a single poll cycle and exit.
- `ct-orchestrator.sh help` — show usage.

Follow the daemon with `journalctl --user -u carbotracker-orchestrator -f`.

## Design notes

- Branch/worktree naming is derived once in the poll loop (`slugify`) and
  handed to `ct_worktree_add`, so the state file and the actual worktree can
  never drift apart.
- A failed step un-claims the ticket and removes the worktree and branch, so
  the next poll starts clean. This means push/PR failures retry the whole
  `opencode` run, which is wasteful but simple and safe. Cleanup is guarded:
  only a worktree this run actually created (`CT_WORKTREE_CREATED`) is
  removed, so a parallel orchestrator that loses the claim race never deletes
  the winner's worktree.
- Review detection compares strictly against the watermark, and the watermark
  advances past the agent's own replies after a round, so a successful round
  never re-triggers on itself. A failed round keeps the watermark in place
  so the same review is retried — capped by `ORCHESTRATOR_REVIEW_RETRIES`,
  after which the orchestrator backs off until a human comments or merges.
- `orchestrator_log` writes to stderr: several helpers return their value on
  stdout inside `$(...)`, so log lines must never land there.
