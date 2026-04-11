# Merge mechanics

This file defines the exact procedure for applying a merge — taking a proposal item and appending it to the target knowledge file, then cleaning up. It's the shared logic between `learn-auto-review` (which has Claude make the decision) and `merge` (which has the human make the decision).

The difference between the two skills is **who decides**. This file defines **how the decision is applied**.

Both skills must follow this procedure exactly so that:
- `patterns.md` and persona files stay consistently formatted
- The audit log stays complete and parseable
- `rollback` can reverse any merge, regardless of which skill applied it

## Inputs every merge operation needs

- **`target_file`** — where the merged content goes (`<data_dir>/patterns.md`, `<data_dir>/personas/<username>.md`)
- **`target_section`** — which section of the target file to append to. For patterns.md this is always "the end of the file with the next available pattern number." For persona files this is one of `## Principles`, `## Anti-patterns`, `## Example PRs`, `## Notes from review comments`
- **`proposal_file`** — the source file in `<data_dir>/proposed/`
- **`proposal_item`** — the specific item within the proposal file being merged (a file may contain multiple items)
- **`decision_source`** — one of `human` (from `merge` subskill) or `auto-review` (from `learn-auto-review`)
- **`decision_reason`** — short explanation of why this was accepted (for the audit log)

## The procedure

Do these steps in order. If any step fails, **do not proceed to the next step** — roll back what you've done (delete temp files, don't touch the proposal or target) and report the failure.

### Step 1 — Read the target file

Open `target_file`. If it doesn't exist, create it with a minimal header — for `patterns.md` that's just `# Team patterns\n\nRules the team enforces in review.\n\n`. For persona files, create the frontmatter + section headers from the template in `persona-schema.md`.

### Step 2 — Determine where to append

**For `patterns.md`**:
- Scan existing headings for `## Pattern #<N>:` and find the highest N
- The new pattern gets number N+1
- Append at the end of the file

**For persona files**:
- Find the heading matching `target_section` (e.g. `## Principles`)
- If the section doesn't exist, add it (use the order from `persona-schema.md`)
- Append the new item at the end of that section, before the next `## ` heading

### Step 3 — Format the appended content

Use the existing formatting style of the target file. Specifically:

**For patterns**:
```markdown
## Pattern #<N>: <rule title>
**Why**: <the reason, from the proposal evidence>
**Source**: <PR links with reviewer attribution, from the proposal>
```

**For persona principles / anti-patterns**:
```markdown
- <rule statement>. Reason: <why>. See PR #<N> (<reviewer>).
```

**For persona example PRs**:
```markdown
- #<N> — <one-line description>
```

**For persona review quotes**:
```markdown
> "<verbatim quote>" — PR #<N>
```

Never invent these formats — if the existing file uses a different shape, match it. Consistency across old and new entries is more important than "correct" formatting.

### Step 4 — Atomic write to the target file

Do NOT overwrite the target file in place. Use a temp-and-rename pattern:

1. Write the new full content (old content + appended item) to `<target_file>.tmp`
2. Verify the temp file is syntactically readable (e.g., `head` succeeds, no truncation)
3. Rename (`mv`) the temp file over the target

This guarantees that a crash mid-write cannot corrupt the target — either the old version is intact or the new version is fully in place, never a half-written file.

### Step 5 — Remove the merged item from the proposal file

The proposal file may contain multiple items. Remove only the one that was merged:

1. Read the full proposal file
2. Identify the specific item by its heading or first line
3. Remove that item's block (from its heading to the next heading, or to the end of the file)
4. If the proposal file is now empty (or contains only a frontmatter / summary header with no items), delete it entirely
5. If items remain, atomic-write the reduced proposal file the same way as the target

### Step 6 — Append to the audit log

Add one JSON line to `<data_dir>/proposed/.auto-review-log`, following the schema in `audit-log.md`. The line records:
- Timestamp
- Decision source (human or auto-review)
- Decision (`merge`)
- Target file and section
- Item title
- The exact diff applied (for rollback to reverse)
- Proposal file path (so rollback can restore the item if needed)
- Reason

The log is append-only. Never rewrite or truncate it.

### Step 7 — Done

Move on to the next proposal item, or exit cleanly if this was the last one.

## Rejecting an item (not the same as skipping)

Both skills can also **reject** an item — delete it from the proposal without applying it. Reject is used when:
- The human (in `merge`) explicitly says "no"
- Claude (in `auto-review`) classifies the item as noise

Reject procedure:
1. Remove the item from the proposal file (steps 5 above, minus the merge)
2. Append an audit log entry with decision `reject` and a short reason
3. Do NOT touch the target file — rejection never modifies knowledge

Rejection is permanent in the sense that the proposal is gone, but **the original PR comments that generated it are still on GitHub**. If a user later decides a rejection was wrong, they can manually add the rule or re-run backfill on the same window. The audit log records every rejection so the user can spot-check.

## Skipping an item (no action)

Both skills can also **skip** an item — leave it in the proposal file untouched, for later review.

Skip procedure:
1. Do nothing to the proposal file
2. Append an audit log entry with decision `skip` and a reason
3. Move on

Skips are common in `auto-review` (ambiguous items wait for human review) and rare in `merge` (the user is already reviewing; why would they skip?). But both support it.

## Idempotency

Running a merge twice on the same item should NOT produce two copies in the target file. Before step 3, scan the target file for an item with the same title or same PR source. If found, skip the merge and log a `skip` with reason `already merged`.

This is defensive — in practice the proposal file removal in step 5 prevents double-merging, but a crash between step 4 and step 5 could leave the target updated with the proposal item still present. The idempotency check catches this.

## Concurrency

Only one merge process should run at a time per repo. Before starting, take a lock file at `<data_dir>/proposed/.merge.lock`. If the lock is already present, tell the user another merge is in progress and exit. Remove the lock on exit (success or failure).

This covers:
- User running `merge` manually while `auto-review` cron fires
- Two `auto-review` runs overlapping (shouldn't happen but defensive)
- User running two `merge` sessions in two terminals

## What this procedure deliberately does NOT do

- **Does not decide** — decisions come from the calling skill (human or Claude)
- **Does not format the *content* of the rule** — formatting is rendering the rule using the target's style, not rewriting what the rule says
- **Does not resolve conflicts between proposals** — if two proposals add conflicting rules, both get merged (they'll show up side by side in `patterns.md`, and the human notices on next review)
- **Does not touch files outside `<data_dir>`** — merge mechanics are purely about the knowledge base
- **Does not emit notifications** — that's `share`'s job, triggered by whatever calling skill needs it
