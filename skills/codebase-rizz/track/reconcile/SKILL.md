---
name: codebase-rizz-track-reconcile
description: Daily cron that checks feature-ownership.md against actual PR activity. Moves completed features from Active to Completed, flags mismatches where the recorded engineer differs from the actual PR author, and prunes stale active entries. Reports findings — never silently rewrites ownership.
---

# track / reconcile

Daily cron. Keeps `feature-ownership.md` accurate by cross-checking it against real PR activity. Ownership is declared by humans via `track/assign`; this subskill verifies.

## Schedule

Default: daily at 7:00am (after both learn crons finish). Configured via `crons.track_reconcile`.

## What it checks

For every entry under `## Active` in `.codebase-rizz/feature-ownership.md`:

1. **Is the branch still active?** If the entry has a `Branch` field, check whether the branch exists and has recent commits.
   ```bash
   gh api "repos/<repo>/branches/<branch>" 2>/dev/null
   ```
   If the branch is deleted and was merged into the default branch, that's a completion signal.

2. **Was the work actually merged?** Check if any PR from that branch was merged:
   ```bash
   gh pr list --repo <repo> --head <branch> --state merged --json number,mergedAt,author
   ```

3. **Did the right person do the work?** If the merged PR's author doesn't match the assigned engineer, that's a mismatch worth surfacing. It might be:
   - A handoff (original engineer moved on, someone else finished)
   - A wrong assignment (typo in username, or the user guessed)
   - Genuinely a different person (pairing, team swap)

4. **Is the entry stale?** If an active entry has a start date more than 30 days ago with no merged PR and no recent branch activity, flag it. Features shouldn't sit in "active" forever.

## What to do with the findings

**Automatic moves (safe):**
- An entry whose branch was merged with the correct author: move from `## Active` to `## Completed (last 30 days)` with today's date as `Completed`
- An entry in Completed older than 30 days: remove (pruning)

**Findings to report, not act on:**
- Mismatched author on a merged PR
- Stale entries (>30 days, no activity)
- Entries with branches that never got a PR

Report these to the user (or log to a daily report file) with enough context to decide. Don't edit the file to "fix" these — the user might have a reason.

## Report format

Save to `.codebase-rizz/proposed/reconcile-YYYY-MM-DD.md` on days when there's something to report. Skip writing the file on clean days — no noise.

```markdown
# Ownership reconcile — 2026-04-10

## Auto-moved to completed (2)
- minh2 — CRM quick actions (merged in PR #XXXX, 2026-04-09)
- eliang — button v2 (merged in PR #XXXX, 2026-04-08)

## Mismatches (1)
### anthnykr assigned "auth middleware rewrite", but PR #XXXX was merged by minh2
- **Branch**: auth-rewrite-v2
- **Possible reasons**: handoff, pair work, wrong assignment
- **Suggestion**: update the assignment if this was a handoff

## Stale entries (1)
### minh2 — "WebSocket experiment" (started 2026-02-15, 54 days old)
- **Branch**: `ws-spike` — last commit 2026-03-01
- **Suggestion**: mark abandoned, or move to completed if landed under a different branch
```

## Why this design

Ownership tracking is load-bearing for `learn/from-persona-code` (which uses it to weight observations) and for `code-like-auto` (which can say "Minh is currently working on CRM stuff, this task is about CRM, route to Minh"). If the ownership log drifts from reality, both of those get quietly worse.

But ownership is also a human thing — people pair, hand off, swap scope — and auto-rewriting it would erase context the team cares about. So: move the *obvious* cases (clean merge with correct author), and report everything else for a human to interpret.

## Failure modes

- **`feature-ownership.md` missing** — skip silently, nothing to reconcile
- **`feature-ownership.md` exists but has no `## Active` section** — skip silently
- **gh rate limit** — bail, don't make partial edits, next run will retry
