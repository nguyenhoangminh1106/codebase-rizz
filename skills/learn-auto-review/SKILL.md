---
name: learn-auto-review
description: Opt-in weekly cron that reads pending proposals, has Claude review each one, and either merges it into patterns.md / persona files, rejects it as noise, or skips it for human review. Off by default — users opt in during bootstrap. Every decision is logged and reversible via the rollback subskill. Use when the user wants codebase-rizz to reduce their manual merge workload without losing auditability.
---

# learn / auto-review

A separate, opt-in cron that has permission to modify knowledge files. Every other `learn/*` cron only writes to `proposed/` — this one is the exception. Because of that, the bar for "merge" has to be strict, the audit trail has to be complete, and the user has to actively opt in (default off).

## Before doing anything

1. Run the preflight from `../_shared/paths.md` to resolve `<data_dir>`. As a multi-repo cron, iterate every registry entry and run the preflight per repo; skip non-bootstrapped repos with a warning
2. Read `<data_dir>/rizz.config.json` and check `auto_review.mode`. If missing or `off`, stop silently — this repo has not opted in. If `dry_run`, proceed but write to a dry-run log instead of touching real files. If `on`, proceed normally

## Schedule

Default: Sunday 10:00am (after `from-codebase` and `patterns-drift` have finished). Configured via `crons.auto_review` and loaded as a launchd user agent by bootstrap. See `../_shared/crons.md`.

## Inputs per run

- `<data_dir>/proposed/patterns/*.md` — all pending pattern proposals
- `<data_dir>/proposed/personas/*.md` — all pending persona proposals
- `<data_dir>/patterns.md` — current team patterns (to check for duplicates and to append to)
- `<data_dir>/personas/*.md` — current persona files
- `<data_dir>/rizz.config.json` — config, especially `trusted_reviewers` and `auto_review.max_merges_per_run`

Skip `proposed/reconcile-*.md` and drift reports — auto-review only handles pattern and persona proposals. Ownership reconciliation and drift are always human-only.

**Also skip any file whose name starts with `backfill-`** (e.g. `proposed/patterns/backfill-2026-04-11.md`, `proposed/personas/minh2-backfill-2026-04-11.md`). Backfill proposals come from the `backfill/` subskill, which scans long historical windows. Auto-merging backfill output is too risky — the volume means a bad decision could inject 10+ bad rules in one run, with blast radius we don't want. Backfill proposals are human-reviewed only, always.

## The review decision

For each individual item inside a proposal file (a proposal file may contain multiple items), Claude decides one of three outcomes. The decision must be explicit and include a one-line reason.

**MERGE** — append to the target file. Requires **all** of:
- **Evidence count ≥ 3**. Fewer than 3 supporting comments is not enough signal to auto-merge, even if the rule looks reasonable
- **At least 2 distinct reviewers** from `trusted_reviewers`. One reviewer repeating themselves is one opinion, not a team pattern
- **Not a duplicate or near-duplicate** of anything already in the target file. Semantic check, not just string match — "prefer findUnique over findFirst" and "use findUnique when querying by unique key" are the same rule
- **The rule has a clear *why*** — derived from the evidence, not just asserted. If the proposal only says "do X" without explaining *why*, skip it for human review
- **Not an amendment** to an existing rule. Amendments touch existing content and need human eyes for tone and consistency. Only brand-new rules can auto-merge
- **Claude's own confidence ≥ 0.85** on a 0-1 scale. Ask Claude to rate "how confident am I that this is a real team pattern worth codifying?" and only merge if it's high

**REJECT** — delete from the proposal file. Use when:
- The item is noise (style, formatting, lint-fixable, typos)
- It's a duplicate of an existing rule with no new information
- The evidence is all from one reviewer or from non-`trusted_reviewers`
- The rule is so specific to one PR that it doesn't generalize
- The proposal text is garbled or incomplete

Rejection is **permanent** — the item is gone from the proposal file, not moved. Rejection reason goes in the audit log so the user can see why. If a user later realizes a rejection was wrong, they rely on the original PR comments (still in GitHub) rather than on the proposal file.

**SKIP** — leave in the proposal file for human review. Use when:
- Genuine ambiguity about whether the rule is real
- It's an amendment to an existing rule (always SKIP — auto-review never touches existing rules)
- It's a persona update that changes the engineer's voice in a non-trivial way
- Any signal that Claude isn't sure

When in doubt, SKIP. False skips just mean the user sees it in manual review — cheap. False merges pollute the knowledge base — expensive.

## The max-merges cap

Read `auto_review.max_merges_per_run` from config (default 5). Stop merging after the cap is hit in a single run, even if more items would qualify. If the cron wants to merge more than 5 things in one run, something is off — either the proposal backlog is huge (user hasn't been reviewing) or Claude is being over-eager. Either way, capping forces the user to notice.

Items beyond the cap stay in the proposal file and get re-considered next run.

## Applying a merge

Follow the procedure in `../_shared/merge-mechanics.md`. That file defines the exact steps (append to the right section, preserve existing formatting, atomic write, clean up the proposal, write the audit log entry, idempotency check, concurrency lock). Every merge from this skill uses the same procedure as `merge` (the human-driven equivalent) so `rollback` can reverse either one.

When calling the shared merge mechanics from this subskill, set `decision_source: "auto-review"` and build the `decision_reason` from the criteria Claude used to approve the merge (e.g. `"3 reviewers, clear why, confidence 0.91"`).

## Dry-run mode

When `auto_review.mode` is `dry_run`:
- Do everything the normal pipeline does EXCEPT write to target files
- Do NOT remove items from proposal files
- Write what *would* have been merged/rejected to `<data_dir>/proposed/.auto-review-dry-run-YYYY-MM-DD.md`
- The user reviews this file. If it looks right, they flip the mode to `on` in config
- Dry-run mode is the recommended starting point for any new setup — it lets users build trust in Claude's judgment before giving it write access

## Audit log

Every decision (in any mode) appends one JSON line to `<data_dir>/proposed/.auto-review-log`. The schema, fields, and invariants are defined in `../_shared/audit-log.md` — follow it exactly so `rollback` can parse every entry regardless of which skill wrote it.

For auto-review entries, set `source: "auto-review"` and include the current `auto_review.mode` in the `mode` field. Every `merge` decision must include the `diff_applied` field with the exact appended text — without it, rollback cannot reverse the decision.

## Notifying the user

After the run, build a summary payload like:

```
Merged: 3 patterns, 1 persona update
Rejected: 8 items (noise)
Skipped: 4 items awaiting your review
Audit log: <data_dir>/proposed/.auto-review-log
Rollback any merge: /codebase-rizz:rollback
```

Always print this summary to the log (stdout/stderr of the launchd run, or the interactive output if invoked manually). It ends up in `~/.codebase-rizz/logs/<slug>/learn-auto-review.log`, which is the user's source of truth for what happened.

If `notifications.enabled` and `notifications.events.auto_review_complete` is `true`, also write the summary to `<data_dir>/proposed/.auto-review-notify-queue.json` so that the next run of `/codebase-rizz:share` (manual or scheduled) picks it up and delivers via Gmail/Slack/fallback. This handoff-through-file pattern avoids cross-skill calls while still letting the user configure notification routing once in share-setup.

## Failure modes

- **`patterns.md` missing**: skip merges that target patterns, still process persona proposals. Log a warning
- **Two simultaneous runs** (shouldn't happen with launchd but defensive): write a lock file `<data_dir>/proposed/.auto-review.lock` before starting, remove on exit. If the lock is already present, skip this run
- **Proposal file parse error**: skip that proposal, don't block the rest of the run
- **Claude decision is unparseable**: treat as SKIP and log the raw response for debugging
- **Max merges hit**: stop merging, continue rejecting/skipping the rest, report in summary

## What this subskill does NOT do

- **Does not touch non-pattern/non-persona proposals** (reconcile, drift reports stay human-only)
- **Does not amend existing rules** — only appends new ones
- **Does not delete persona files** — only appends to their sections
- **Does not run if `auto_review.mode` is `off`** — silent no-op
- **Does not bypass `trusted_reviewers`** — an item with zero trusted-reviewer backing can never merge, regardless of other signals
