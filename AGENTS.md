## Agent skills

### Human PR reviews

When a human reviews a PR and threads come back on your branch, run the `/review-comments` skill: it fetches the review, classifies each comment (agree / push-back / clarify), settles with the user, implements via `/implement`, and replies on every thread. Route this from the main flow's `/code-review` step when the reviewer is a person rather than this agent — `ask-matt`'s router doesn't know about it, it's this repo's own skill.

### Issue tracker

Issues and PRDs live as GitHub issues in this repo, managed via the `gh` CLI. Every agent-created issue carries an `ai-created` label and a `_Created by carbotracker's agent skills._` footer so AI-generated tracking entries are always distinguishable from hand-written ones. See `docs/agents/issue-tracker.md`.

### Triage labels

Triage uses the five default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at the repo root and `docs/adr/` for decisions. See `docs/agents/domain.md`.
