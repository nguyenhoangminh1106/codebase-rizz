# Audit log format

Every skill that makes a merge, reject, skip, or rollback decision appends one JSON line to `<data_dir>/proposed/.auto-review-log`. The log is the single source of truth for:

- What changed in the knowledge base and when
- Why it changed (the decision reason)
- Who decided (human via `merge`, Claude via `learn-auto-review`, or a `rollback` reversing a previous decision)
- How to reverse any specific decision (the `diff_applied` field)

Three skills read or write this log: `learn-auto-review` (writes merge/reject/skip decisions), `merge` (writes the same), and `rollback` (reads to show history, writes rollback entries that reference prior merges). Getting the format right matters because cross-skill parsing depends on it.

## File location

`<data_dir>/proposed/.auto-review-log`

Historical note: the file is named `.auto-review-log` even though `merge` also writes to it. Renaming it would break backward compatibility with older versions of the plugin. Treat the name as a fixed convention, not a description of content.

## Format

**One JSON object per line** (JSONL / newline-delimited JSON). No pretty-printing, no indentation — that breaks line-at-a-time parsing.

Append-only. Never truncate, rewrite, or delete lines from this file. `rollback` undoes decisions by **adding a new line**, not by removing the original.

## Schema

Every entry has these fields, in this order (order doesn't matter for JSON correctness but consistency helps when eyeballing):

```json
{
  "ts": "2026-04-11T10:00:12Z",
  "source": "auto-review",
  "mode": "on",
  "decision": "merge",
  "target_file": "patterns.md",
  "target_section": "end",
  "item_title": "Prefer findUnique over findFirst for unique keys",
  "proposal_file": "proposed/patterns/2026-04-10.md",
  "diff_applied": "## Pattern #42: Prefer findUnique over findFirst for unique keys\n**Why**: ...\n**Source**: PR #8865, #9001, #9105\n",
  "reason": "3 reviewers, clear why, high Claude confidence"
}
```

## Field meanings

- **`ts`** (required) — ISO 8601 UTC timestamp. Always UTC, never local time. Use `Z` suffix, not `+00:00`
- **`source`** (required) — which skill wrote this line. One of:
  - `"auto-review"` — written by `learn-auto-review`
  - `"merge"` — written by the human-driven `merge` skill
  - `"rollback"` — written by `rollback` when reversing a previous decision
- **`mode`** (required for `source: "auto-review"`, optional otherwise) — one of `off`, `dry_run`, `on`. For `merge` and `rollback` entries, this field can be omitted or set to `null`
- **`decision`** (required) — one of:
  - `"merge"` — the item was appended to the target file
  - `"reject"` — the item was deleted from the proposal without being merged
  - `"skip"` — the item was left in place for later review
  - `"rollback"` — a prior merge was reversed
- **`target_file`** (required for merge/rollback, optional otherwise) — path to the file that was modified, relative to `<data_dir>` (e.g. `patterns.md`, `personas/minh2.md`)
- **`target_section`** (required for persona merges) — which section of the target file was touched. For `patterns.md` this is always `"end"`. For persona files, one of `"principles"`, `"anti-patterns"`, `"example-prs"`, `"review-quotes"`
- **`item_title`** (required) — a short human-readable title for the item. For patterns, this is the rule statement. For persona additions, it's the principle or the first sentence of the item. Used by `rollback` to show the user what they're about to undo
- **`proposal_file`** (required) — path to the source proposal file, relative to `<data_dir>`. Used by `rollback` to restore an item if the user wants to re-review it
- **`diff_applied`** (required for merge decisions) — the exact text that was appended to the target file. This is the most important field for `rollback` — it lets the rollback skill find and remove the exact block from the target. Include trailing whitespace and newlines so the match is byte-exact
- **`reason`** (required) — short explanation of why this decision was made. For `auto-review` entries, this is Claude's justification ("3 reviewers, clear why, high confidence"). For `merge` entries, the human can provide a reason or the skill can default to `"user accepted"`. For `reject` entries, the reason is the fail-the-filter diagnosis
- **`original_merge_ts`** (only for rollback entries) — the `ts` of the merge being rolled back. Lets `rollback` detect double-rollback attempts and show "already rolled back" in the history

## Examples

**Auto-review merges a pattern:**
```json
{"ts":"2026-04-11T10:00:12Z","source":"auto-review","mode":"on","decision":"merge","target_file":"patterns.md","target_section":"end","item_title":"Prefer findUnique over findFirst for unique keys","proposal_file":"proposed/patterns/2026-04-10.md","diff_applied":"## Pattern #42: Prefer findUnique over findFirst for unique keys\n**Why**: findFirst implies multiple matches are possible. findUnique signals intent and is clearer at the call site.\n**Source**: PR #8865, PR #9001, PR #9105\n","reason":"3 reviewers (owen-paraform, anthnykr, taneliang), clear why, confidence 0.91"}
```

**Human rejects an item via `merge`:**
```json
{"ts":"2026-04-11T14:22:18Z","source":"merge","decision":"reject","item_title":"Use camelCase for variables","proposal_file":"proposed/patterns/2026-04-10.md","reason":"style rule, belongs in linter not patterns"}
```

**Auto-review skips an ambiguous item:**
```json
{"ts":"2026-04-11T10:00:14Z","source":"auto-review","mode":"on","decision":"skip","item_title":"Amendment to pattern #7: also applies to read_only_prisma","proposal_file":"proposed/patterns/2026-04-10.md","reason":"amendments always skip, human should review"}
```

**Rollback reverses a previous merge:**
```json
{"ts":"2026-04-11T15:22:00Z","source":"rollback","decision":"rollback","target_file":"patterns.md","item_title":"Prefer findUnique over findFirst for unique keys","proposal_file":"proposed/patterns/rollback-2026-04-11.md","reason":"user rolled back via rollback subskill","original_merge_ts":"2026-04-11T10:00:12Z"}
```

Note the rollback entry's `proposal_file` points at a **newly-created** rollback proposal file where the skill restored the item for potential re-review, not the original proposal (which was already modified when the merge happened).

## Reading the log

To show recent merges in `rollback`:
```bash
tail -100 <data_dir>/proposed/.auto-review-log \
  | jq -c 'select(.decision == "merge" and .source != "rollback")'
```

To see how many rollbacks you've needed to do (signal that auto-review is too aggressive):
```bash
grep '"decision":"rollback"' <data_dir>/proposed/.auto-review-log | wc -l
```

To see what auto-review has rejected (signal that the quality filter is catching noise):
```bash
grep '"source":"auto-review"' <data_dir>/proposed/.auto-review-log \
  | jq -c 'select(.decision == "reject") | {item_title, reason}'
```

## Invariants

These must always hold. If any skill violates them, `rollback` may misbehave.

1. **Append-only.** Never delete lines. Rollback adds a new line; it does not edit old ones
2. **Monotonic timestamps.** Each appended line should have `ts >= the previous line`. Use a file lock if two writers might race
3. **Valid JSON per line.** Corrupt lines break every reader. If you can't serialize a field (e.g., a value containing control characters), escape it — don't skip the line
4. **Rollback entries reference real merges.** An `original_merge_ts` in a rollback entry should match a `ts` in an earlier merge entry. If it doesn't, something is inconsistent
5. **No ambiguous item titles within a single proposal file.** `rollback` uses `(proposal_file, item_title)` as the key to identify what to restore. If two items in the same proposal have the same title, rollback can't distinguish them. Skills must disambiguate at write time (e.g., append a short ID)
