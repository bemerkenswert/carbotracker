---
name: review-comments
description: Respond to and implement a colleague's review comments on a pull request. Fetch the review (general + inline threads), classify each comment, discuss with the dev, implement the agreed ones, and reply on every thread before the PR is re-reviewed. Use when the user says a review came in on a PR and they want you to look at it, talk about the comments, implement them, resolve threads, or "take a look at the review".
---

# Review comments

A human reviewed a PR and left comments. Every review is a **round-trip**: the PR goes out, comes back with threads, and leaves again. Each round-trip has the same shape — **fetch → classify → discuss → implement → reply** — and this skill drives it to a clean pass.

The issue tracker should have been provided to you — run `/setup-matt-pocock-skills` if `docs/agents/issue-tracker.md` is missing.

## Process

### 1. Fetch the review

A GitHub review splits across two surfaces — collect both:

- **General comments** (the review's overall message): `gh pr view <n> --comments`.
- **Inline threads**, which live on the diff, _not_ the issue thread — `gh pr view <n> --comments` shows only the top of each thread:
  - Diff comments: `gh api repos/<owner>/<repo>/pulls/<n>/comments` — one entry per comment, each with `path`, `line`, and `in_reply_to`, so threads string together via `in_reply_to`.
  - Review-level comments: `gh api repos/<owner>/<repo>/pulls/<n>/reviews` for the review bodies.
  - Resolution markers land on the comment resource as `resolved` / `dismissed` via `gh api repos/<owner>/<repo>/pulls/<n>/comments/<id>` if you need thread state.
- The repo and pull number: `gh pr view <n>` inside the clone infers the repo from the remote.

**Done when** every thread and general comment for the PR is captured, each tagged with its `path` + `line` (inline) or its review (general). A thread with replies is one point to address, not several.

### 2. Classify

Sort every point into exactly one bucket, with a one-line reason each:

- **agree** — the comment is right, or at least cheap to satisfy; do it.
- **push-back** — reasoned disagreement: the change would hurt, or the comment misunderstands the code. You will _argue_, not silently change.
- **clarify** — the comment hinges on information you don't have, or its intent is genuinely ambiguous.

Two pruning rules:

- If a comment duplicates a point of your own, or contradicts other evidence in the branch, that pushes it toward **push-back** / **clarify** rather than silent agreement.
- If you are unsure a point is real, run `/code-review` on the same diff first — don't ask the human what your own review would have caught.

**Done when** every comment has a bucket and a one-line reason you could defend.

### 3. Discuss with the dev

Present the classification — per comment: what the reviewer said (file + line), your bucket, your reasoning, and your proposed reply or change. Get the caller's call on each **push-back** and **clarify** before acting. Never override a colleague's comment by silence.

**Done when** the dev has settled every point: which to implement, which to answer with an argument, which need a clarifying question.

### 4. Implement

For the **agree** set, run the `/implement` flow, driving `/tdd` internally for any behaviour change — one red-green slice at a time. After implementing, if the caller wants it, `/code-review` the diff again so you don't ship a change that reintroduces a fresh Standards/Spec finding.

Stay scoped: implement only the agreed comments. A reviewer's remark you disagreed with gets a reply, not code.

**Done when** every agreed comment is implemented, and tests + tsc + lint + build are green.

### 5. Reply on every thread

Respond to each thread on the PR with a pointer back at it:

- **Implemented** → reply that quotes the point and says what changed (commit/behaviour), then resolve the thread.
- **Push-back** → leave the thread **open**, reply with the argument, and invite the reviewer to close it once convinced.
- **Clarify** → reply with the question; keep it open until answered.

Reply _to the thread_, not to the PR. A threaded inline reply is created with `POST /repos/{owner}/{repo}/pulls/{n}/comments/{comment_id}/replies` (body only); `gh api repos/{owner}/{repo}/pulls/{n}/comments/{comment_id}/replies -f body="..."`. Resolve an inline thread via `PUT .../comments/{comment_id}` with `{ "resolved": true }`. A general comment is a plain issue reply: `gh issue comment <n> --body "..."`.

**Agent-authored replies MUST carry the AI-source footer** — a colleague reading the thread must be able to tell your reply from the human's. Append this footer line to every reply body:

```
---
_Created by carbotracker's agent skills._
```

If the caller (the dev you're implementing for) wants a reply signed as themselves instead, they must say so explicitly before you post — ask if you're unsure. Never post a reply without either the footer or an explicit sign-as-them instruction.

**Done when** every thread has a response, resolved threads are resolved, and open threads are deliberately left for the reviewer.

## Round-trip closed

Summarise the round-trip: how many comments, how many implemented/pushed-back/clarified, any thread left open, and whether a new review or push to the branch is the next move.
