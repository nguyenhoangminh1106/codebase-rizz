---
name: merge
description: Interactively walk through every pending proposal in <data_dir>/proposed/ and let the user accept, reject, skip, or edit each item. Applies accepted items to patterns.md and persona files using the shared merge mechanics, logs every decision, and cleans up proposal files. Use when the user wants to burn down their proposal backlog — especially after running backfill, or on any day when the daily crons have produced more than a handful of items to review. This is the human-driven counterpart to learn-auto-review.
---

# merge

The human-driven merge walkthrough. Every decision is the user's; this skill just handles the listing, prompting, and mechanical file surgery so the user can focus on judgment.

## Before doing anything

Run the preflight from `../_shared/paths.md` to resolve `<data_dir>` for the current repo. Stop with the guidance in that file if any preflight step fails.

## What this skill does

1. Lists every proposal file under `<data_dir>/proposed/patterns/` and `<data_dir>/proposed/personas/`
2. For each file, walks through the individual items inside
3. For each item, shows the user the content and asks: **accept, reject, edit, skip, or quit**
4. Applies each decision using the shared merge mechanics in `../_shared/merge-mechanics.md`
5. Writes every decision to the audit log using the schema in `../_shared/audit-log.md`
6. At the end, prints a summary of what was merged, rejected, skipped, and how many items are still pending

## The interactive flow

### Step 1 — List pending proposals

Read the `proposed/` folder. Group files by category:

- **Pattern proposals** — `proposed/patterns/*.md` (including `backfill-*.md`, `backfill-overflow-*.md`, `drift-*.md`)
- **Persona proposals** — `proposed/personas/*.md` (including `*-backfill-*.md`)
- **Reconcile proposals** — `proposed/reconcile-*.md` (informational, not merge-able — `merge` skips these and tells the user to handle them in `track/assign` or by editing `feature-ownership.md`)

Count items per file (not just files) so the user knows the true workload. A single proposal file may contain 10 items.

Print a summary before starting:

> I found **N items across M files** pending your review:
>
> - Patterns: X items across Y files (including backfill-*, drift-*)
> - Personas: X items across Y files (including backfill-*)
>
> I'll walk you through each item. Per item you can: (a) accept and I'll merge it, (r) reject and I'll drop it, (e) edit before accepting, (s) skip and leave for later, (q) quit. Ready? (y/n)

Unlike `learn-auto-review`, `merge` **does process backfill-prefixed files** — the whole point of backfill is that a human reviews its output, and this skill is that human. Auto-review's skip rule does not apply here.

### Step 2 — Walk through each item

For each item in each proposal file, show:

```
── Item 3 of 8 in proposed/patterns/backfill-2026-04-11.md ──

[new pattern] Prefer findUnique over findFirst for unique keys

Why: findFirst implies multiple matches are possible. findUnique signals intent and is clearer at the call site.

Evidence:
  - PR #8865, owen-paraform: "this should be a findunique"
  - PR #9001, anthnykr: "nit: use findUnique since id is a pk"
  - PR #9105, taneliang: "prefer findUnique here"

Target: patterns.md (would become pattern #42)

(a)ccept  (r)eject  (e)dit  (s)kip  (q)uit  ?
```

Show enough context that the user can decide in 5 seconds — not every character of the proposal, but the title, the why, the evidence, and where it would land. If the item is a persona addition, also show which engineer it's for and which section it would join.

### Step 3 — Handle the user's choice

**Accept** — apply the merge per `../_shared/merge-mechanics.md`. Use `decision_source: "human"` and `decision_reason: "user accepted"`. Move on to the next item.

**Reject** — remove the item from the proposal file without touching the target. Write an audit log entry with `decision: "reject"`. Prompt once for a short reason ("why reject?" — optional, press enter to use "user rejected"). Move on.

**Edit** — open the item text in `$EDITOR` (or `nano` as fallback). The user can tweak the rule wording, the evidence list, or anything else. When they save and exit, re-show the edited content and ask again: (a)ccept, (r)eject, (s)kip. Edit is not a final answer — it always leads to another decision.

**Skip** — leave the item in the proposal file untouched. Write an audit log entry with `decision: "skip"` and `reason: "user skipped for later review"`. Move on.

**Quit** — stop the walkthrough. Save any pending state, print a partial summary, exit cleanly. Nothing merged or rejected is ever lost — everything is committed per-item as the user decides, so a quit in the middle leaves both the target files and proposal files in a consistent state.

### Step 4 — Summary

After the last item (or on quit), print:

```
── merge session complete ──

Merged: 5 items (4 patterns, 1 persona addition to minh2.md)
Rejected: 3 items
Skipped: 2 items (remain in proposed/ for later review)
Edited before accepting: 1 item

Full audit log: <data_dir>/proposed/.auto-review-log
Rollback any merge: /codebase-rizz:rollback
```

Don't pad the summary with advice unless something notable happened (e.g., "you rejected 10/12 items from proposed/patterns/backfill-2026-04-11.md — if backfill keeps producing mostly-reject output, consider tightening trusted_reviewers or the signal threshold").

## Idempotency and safety

- **Per-item atomic commit.** Each accept, reject, or edit-then-accept writes to disk before the next prompt. A crash or quit in the middle doesn't leave the user with half-merged state
- **Locking.** Merge takes the same lock as `learn-auto-review` (`<data_dir>/proposed/.merge.lock`) so the two can't race on the same proposal
- **Deduplication.** Before applying any merge, the shared mechanics check whether an equivalent item already exists in the target file. If it does, the merge becomes a skip with reason `"already merged"`
- **Rollback** always works. Every merge from this skill shows up in `.auto-review-log` with `source: "human"` and can be reversed via `/codebase-rizz:rollback`, the same as auto-review merges

## What merge does NOT do

- **Does not auto-pick anything.** The user decides every item. If the user wants Claude to pre-filter the obvious ones, they run `learn-auto-review` first (if enabled) and merge the remainder
- **Does not generate articles, personas, or patterns from scratch.** It only consumes proposals that already exist in `proposed/`
- **Does not touch knowledge files outside `<data_dir>`.** Articles, config, and the registry are left alone
- **Does not rewrite the user's decisions retroactively.** If the user rejects an item and later regrets it, they need to run the daily cron or backfill again to regenerate the proposal

## Running against reconcile and drift proposals

- **`proposed/reconcile-*.md`** — contains ownership mismatches, not merge-able items. `merge` prints the contents and tells the user to handle via `/codebase-rizz:track-assign` or by editing `feature-ownership.md` manually. No audit log entry
- **`proposed/patterns/drift-*.md`** — contains suggestions to remove or rewrite *existing* patterns (not new ones). The shared merge mechanics only handle *additions*, not *amendments*. For now, `merge` prints drift proposals and asks the user to review them by hand. A future version of this skill may add interactive amendment support, but v3 doesn't
- **`proposed/patterns/backfill-overflow-*.md`** — handled normally as pattern proposals. The user can work through them if they want the rest of the backfill output

## Failure modes

- **No pending proposals** — print "Nothing to merge. The daily learn crons haven't written anything new, or you've already merged everything." and exit cleanly
- **`patterns.md` missing** — the shared mechanics will create it with a minimal header on first merge. The user doesn't have to pre-create the file
- **A persona file is missing for a persona-addition proposal** — tell the user which username is missing and skip that item (they can re-run `bootstrap` with just that engineer to seed the file, then re-run merge)
- **User hits Ctrl-C mid-session** — treat the same as `q`. Save state, print partial summary, exit
- **Audit log write fails** — this is serious because rollback depends on it. Refuse to apply any merge if the audit log can't be written. Tell the user to check disk space and permissions
