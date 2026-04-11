---
name: backfill
description: Interactive one-time backfill for mature codebases. Scans historical merged PRs in a user-described scope, applies a strict quality filter (only observations that teach code quality, design, or tradeoff reasoning), and writes a single capped proposal file for patterns and persona updates. Never auto-merges, never generates articles. Use when a user has just bootstrapped codebase-rizz on a codebase with months or years of history and wants to seed the knowledge base instead of waiting weeks for the daily crons to accumulate signal.
---

# backfill

Interactive subskill for seeding patterns and personas from historical PRs. Run this once per repo right after `bootstrap`, or again later if the user wants to catch up on a specific window they missed.

Backfill is **not a cron**. It only runs when the user invokes it directly. And it only touches `patterns.md` proposals and persona proposals — **it never generates articles** (that's `learn/from-codebase`'s job) and it **never merges**, even if `auto_review.mode` is `on`.

## Before doing anything

1. **Run the path preflight** from `../_shared/paths.md` to resolve `<data_dir>` for the current repo
2. **Run the gh preflight** from `../_shared/gh-preflight.md` — backfill scans large volumes of PRs and will fail loudly without it
3. **Verify `trusted_reviewers` is populated** in `<data_dir>/rizz.config.json`. If empty, stop and tell the user to add at least one username. Backfill never learns from an uncurated firehose — the same rule as the daily cron, only more so

## The interactive scope prompt

Ask the user to describe what they want backfilled, in plain English:

> **What do you want to backfill?**
>
> Describe it however you like — I'll turn it into a GitHub search and a set of filters. Some examples:
>
> - "Last 3 months of merged PRs, all engineers"
> - "Every PR Minh and Anthony merged since January"
> - "PRs touching the state management code"
> - "The top 20 most-discussed PRs by any of my trusted reviewers"
>
> Or press enter for the default: **last 3 months, all personas in config, PRs with at least 3 review comments**.

Parse the free-form answer into concrete parameters:

- `date_range` — start and end dates (ISO)
- `authors` — list of GitHub usernames, defaults to the `personas` array
- `path_filter` — optional glob or directory filter
- `min_comments` — minimum review comments per PR to consider, defaults to 3
- `target` — `patterns`, `personas`, or `both` (default: both)

If the user's description is ambiguous, ask **one** clarifying question and then commit to the parsed parameters. Don't loop indefinitely refining the scope.

## The dry summary

Before fetching anything, print what backfill is about to do:

> **Backfill plan**
>
> - Scope: <parsed date range, authors, path filter>
> - Target: <patterns | personas | both>
> - Minimum review comments per PR: <min_comments>
> - Trusted reviewers whose comments will be read: <list from config>
>
> I'll fetch merged PRs matching this scope, read review comments from trusted reviewers only, apply the quality filter (only observations that teach code quality or design), cap the proposal at 15 new patterns and 10 additions per persona, and write one proposal file. Nothing gets merged automatically.
>
> Proceed? (y/n, e=edit scope)

If the user picks `e`, re-prompt for the scope. If `n`, stop. If `y`, continue.

## Fetching

Use `gh` to list merged PRs in the scope:

```bash
gh pr list --repo <repo> --state merged --search "merged:<start>..<end>" \
  --json number,title,url,author,mergedAt,additions,deletions,comments \
  --limit 500
```

If the scope has an author filter, combine:

```bash
gh pr list --repo <repo> --state merged --author <username> \
  --search "merged:<start>..<end>" --json ... --limit 500
```

500 is a hard cap per `gh` query. If the user asked for a window that would return more, warn them: "This scope would return more than 500 PRs. I'll process the first 500 by merge date. Re-run with a narrower window to cover the rest."

For each PR in the result, fetch its review comments:

```bash
gh api "repos/<repo>/pulls/<number>/comments" --paginate
```

Filter the comments to only those authored by users in `trusted_reviewers`. Drop comments under 20 characters and any containing `[bot]` in the username. Print progress every 25 PRs so the user knows the run is alive.

If you hit the `gh` rate limit mid-fetch, save progress to `<data_dir>/proposed/.backfill-state.json` (PRs processed so far) and tell the user to re-run backfill with the same scope later — the state file lets it resume.

## The quality filter

Apply the shared quality filter from `../_shared/quality-filter.md` to every candidate observation (a theme extracted from one or more review comments). The filter's one-sentence test, the PASS/FAIL examples, and the "when in doubt, drop" rule all live in that file — read it before running backfill and don't restate the criteria here.

The filter is the **whole point** of backfill. A backfill run that doesn't apply the filter strictly produces exactly the junk it's supposed to prevent: a polluted `patterns.md` full of style nitpicks and readability refactors dressed up as team wisdom. Because backfill scans much larger windows than the daily crons, the filter matters even more here — noise volume scales with window size.

## Thresholds (stricter than daily cron)

The daily `learn/from-pr-comments` cron requires:
- `min_pr_comment_signal` (default 2) repetitions
- Multiple reviewers

Backfill requires MORE because the volume is larger and noise compounds:
- **At least 5 occurrences** of the same theme across the scope
- **At least 3 distinct trusted reviewers** expressing it
- **A clear *why*** present in at least one of the source comments — not just "do X"
- **Not a duplicate** of anything already in `<data_dir>/patterns.md` (semantic check, not string match)

Items failing these thresholds are discarded, not moved to a weaker proposal. Backfill is for the strong signals that should have been learned earlier.

## Deduplication against existing knowledge

Before writing the proposal, for each candidate:

1. Read the current `<data_dir>/patterns.md`. If any existing pattern covers the same principle, skip the candidate. Don't propose amendments in backfill — amendments are subtle and deserve the daily cron's more targeted signal
2. For persona candidates, read the target `<data_dir>/personas/<username>.md`. Same skip rule — if a similar principle is already listed, skip it

Backfill is only for things not yet captured.

## Caps

**Single proposal file per run**, with hard caps:

- Maximum **15 new pattern candidates** in one backfill run
- Maximum **10 additions per persona**
- If Claude finds more candidates that pass the filter, rank them by evidence count and pick the top N. Spill the rest into `<data_dir>/proposed/patterns/backfill-overflow-YYYY-MM-DD.md` and tell the user about it in the summary — they can look if they want more

Caps exist because an overwhelming proposal gets abandoned. 15 high-signal patterns a human will actually review beats 80 mediocre ones they'll skim and ignore.

## Writing the proposal

Write to `<data_dir>/proposed/patterns/backfill-YYYY-MM-DD.md` (and/or `<data_dir>/proposed/personas/<username>-backfill-YYYY-MM-DD.md` per affected persona).

**File naming matters**: the `backfill-` prefix is the signal for `learn/auto-review` to skip these proposals. Auto-review is intentionally blind to backfill output — the volume and historical nature make auto-merge too risky. Humans review backfill output, always.

Use the same structure as the daily cron's proposal format, but include at the top:

```markdown
# Backfill proposal — 2026-04-11

**Scope**: <date range>, <authors>, min <N> comments/PR
**PRs scanned**: <number>
**Trusted reviewer comments considered**: <number>
**Candidates after quality filter**: <number>
**Final proposals after cap and dedup**: <patterns count>, <personas count>

⚠️ Auto-review will skip this file — review and merge manually.

## New patterns (N)
...

## Persona additions
...
```

## Reporting back

After writing the proposal:

- Summary of what was found (PRs scanned, comments considered, final proposal counts)
- Path to the proposal file (and overflow file if any)
- How to review: open the file, scan the candidates, copy the good ones into `patterns.md` and the persona files by hand (or via `merge/` if that subskill exists)
- One-liner: "Backfill is a one-time operation for this scope. For ongoing learning, the daily crons are already running (or will start running on their next scheduled slot)."

## Resuming an interrupted run

If `<data_dir>/proposed/.backfill-state.json` exists at the start of a run, ask the user:

> I see an interrupted backfill from <date> with scope <previous scope>. Do you want to (1) resume it, (2) discard it and start fresh, or (3) keep it and run a new one alongside?

Default to resume. This covers gh rate limits, laptop sleeps, and accidental interruptions.

## What backfill does NOT do

- **Does not generate articles.** That's `learn/from-codebase`'s job — articles need a specific narrative hook and backfill doesn't do human-moment research. If the user wants articles from historical features, they run `learn/from-codebase` manually
- **Does not merge anything into `patterns.md` or persona files.** Proposal-only, always
- **Does not run on a schedule.** No launchd plist, no cron entry. Invoked interactively only
- **Does not process proposals from the trash pile** — if the user's `trusted_reviewers` list doesn't include the people whose comments would have been the best source, backfill will come up empty. That's working as intended; the filter is doing its job
- **Does not touch `feature-ownership.md` or `articles/`**
- **Does not learn from PRs outside the user's scope** — if the user says "last 3 months," backfill doesn't quietly widen the window

## Failure modes

- **`trusted_reviewers` empty or missing**: stop, tell the user to configure it, don't write anything
- **gh rate limit mid-fetch**: save state, tell the user to resume later
- **Zero candidates pass the quality filter**: this is legitimate. Tell the user: "No candidates in this scope passed the quality filter. This usually means the trusted reviewers weren't leaving architectural feedback in this window, or the PRs were mostly small fixes. Try widening the scope or relaxing the `min_comments` parameter." Don't write an empty proposal file
- **gh query returns 500+ PRs**: process the first 500, warn the user
- **Registry missing**: tell the user to run `bootstrap` first
