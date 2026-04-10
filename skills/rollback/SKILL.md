---
name: rollback
description: Reverse a previous auto-review merge by reading the audit log, showing recent merges with their reasons, and letting the user pick any to undo. Removes the merged content from patterns.md or the persona file and (optionally) restores the item to a fresh proposal file for re-review. Use when the user reviews their auto-review audit log and spots a merge that was wrong.
---

# rollback

The safety net for `learn/auto-review`. When Claude merges something the user disagrees with, rollback undoes it cleanly — without requiring git knowledge or manual file surgery.

## Before doing anything

Resolve `<data_dir>` for the current repo via the registry lookup in `../_shared/paths.md`. If the lookup fails, tell the user to run `bootstrap` and stop.

## Read the audit log

Open `<data_dir>/proposed/.auto-review-log`. Each line is a JSON object with fields `ts`, `mode`, `decision`, `target`, `item_title`, `reason`, `diff_applied`, `proposal_file`.

Filter to:
- `decision == "merge"` (you can't roll back a reject or skip — rejects are gone, skips didn't change anything)
- `mode == "on"` (dry-run entries never actually merged, nothing to undo)
- Recent entries first (sort by `ts` descending)

If the log is empty or has no merge entries, tell the user "no auto-merges to roll back" and stop.

## Show the user the merge history

Present the last 20 merges (or however many exist, whichever is smaller) as a numbered list:

```
Recent auto-merges you can roll back:

1. [2026-04-11 10:00]  patterns.md ← "Prefer findUnique over findFirst for unique keys"
     Reason: 3 reviewers, clear why, high confidence
     From: proposed/patterns/2026-04-10.md

2. [2026-04-11 10:00]  personas/minh2.md ← "Avoid forwardRef for cross-tree coordination"
     Reason: 2 reviewers in minh2's own review comments, high confidence
     From: proposed/personas/minh2-2026-04-10.md

3. [2026-04-04 10:00]  patterns.md ← "Use satisfies over as const for Prisma queries"
     ...

Which one do you want to roll back? [1-20, q=quit, m=show more]
```

## Confirm before touching files

When the user picks an entry, show them the exact diff that will be removed:

```
This will remove from patterns.md:

---
## Pattern #42: Prefer findUnique over findFirst for unique keys
**Why**: findFirst implies multiple matches are possible. findUnique signals intent...
**Source**: PR #8865, #9001, #9105
---

Also, the original item will be restored to proposed/patterns/rollback-2026-04-11.md
so you can re-review it if you want.

Proceed? (y/n)
```

Never roll back without this confirmation. Rollback changes committed knowledge, which is the opposite of the usual rule that cron changes need human approval. The confirmation is the parallel check.

## Apply the rollback

1. **Remove the diff from the target file**. Read the current file, find the exact `diff_applied` block, remove it. If the exact block is no longer present (someone edited the file after the merge), stop and tell the user: "I can't safely roll back this merge — the file has been edited since. You'll need to undo manually, either with git or by hand."
2. **Restore the item to a new proposal file** at `<data_dir>/proposed/patterns/rollback-YYYY-MM-DD.md` (or the persona equivalent). This gives the user the option to re-review and potentially re-merge with edits, rather than losing the content entirely
3. **Append a rollback entry to `.auto-review-log`**:
   ```json
   {"ts":"2026-04-11T15:22:00Z","mode":"rollback","decision":"rollback","target":"patterns.md","item_title":"Prefer findUnique...","reason":"user rolled back via rollback subskill","proposal_file":"proposed/patterns/rollback-2026-04-11.md","original_merge_ts":"2026-04-11T10:00:12Z"}
   ```
   The `original_merge_ts` field lets a user see "this was merged then rolled back" in the history, and prevents rolling back the same merge twice

## Multiple rollbacks in one session

After each rollback, ask: "Roll back another one? (y/n)". Users often discover multiple bad merges at once and don't want to re-run the subskill each time.

## What rollback does NOT do

- **Does not touch `rizz.config.json`** — doesn't change `auto_review.mode`. If the user wants to turn off auto-review after a bad merge, they do it separately
- **Does not delete the audit log entry** — the merge stays in history, just marked rolled-back by the new entry. This is on purpose; the history is immutable
- **Does not roll back manual edits** — if the user manually edited `patterns.md` after the auto-merge, rollback refuses rather than guessing
- **Does not roll back reject decisions** — rejected items are gone. If the user wanted them back, they'd need to look at the original PR comments
- **Does not run as a cron** — rollback is strictly interactive. A cron rolling back merges would be absurd

## Edge cases

- **Log entry references a file that no longer exists**: the target file was deleted. Log a warning, skip that entry
- **User tries to roll back the same merge twice**: detect via `original_merge_ts` in the log, tell the user "this merge has already been rolled back"
- **`.auto-review-log` missing**: no merges to roll back, nothing to do, exit cleanly

## Reporting back

After each rollback:
- Which file was modified
- The lines removed
- Path to the restored proposal file
- One-liner: "Run `auto-review` again if you want this reconsidered, or edit the restored proposal first"
