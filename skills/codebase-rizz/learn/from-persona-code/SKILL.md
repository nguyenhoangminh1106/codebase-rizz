---
name: codebase-rizz-learn-from-persona-code
description: For each tracked engineer, scan their recently merged PRs and propose updates to their persona file — new principles, new anti-patterns, new example PRs, new review quotes. Runs as a daily cron but can be invoked manually. Writes to .codebase-rizz/proposed/personas/. Never edits persona files directly.
---

# learn / from-persona-code

Daily cron. Keeps each persona file growing as the engineer writes more code. Complements `learn/from-pr-comments`: that one learns team-wide patterns, this one learns per-engineer voice.

## Schedule

Default: daily at 6:15am (15 min after `from-pr-comments` so the two don't contend for gh rate limit). Configured via `crons.from_persona_code`.

## What it does

For every username in `rizz.config.json`'s `personas` array:

1. **Fetch their PRs merged since last run**:
   ```bash
   gh pr list --repo <repo> --author <username> --state merged \
     --search "merged:>=<last_run>" --json number,title,url,files,additions,deletions
   ```

2. **Fetch their review comments written in the window**:
   ```bash
   gh api "repos/<repo>/pulls/comments" --paginate \
     --jq '.[] | select(.user.login == "<username>" and .created_at >= "<last_run>")'
   ```
   Review comments they leave on *other people's* PRs are usually the richest persona signal — that's where taste shows.

3. **Compare against their existing persona file**. Read `.codebase-rizz/personas/<username>.md`. For each new observation, decide:
   - Is this a *new* principle not yet in the file? → propose as addition
   - Does it *sharpen* an existing principle (adding a condition or a counterexample)? → propose as amendment
   - Is it just a repeat of what's already there? → skip, don't noise up the proposal

4. **Synthesize the observations**. Things worth extracting:
   - **New principles** — derived from patterns in the engineer's own code (e.g., always using `satisfies` over `as const` across multiple PRs)
   - **New anti-patterns** — things they pushed back on in review
   - **New example PRs** — representative merges worth citing
   - **New review quotes** — direct quotes that capture their voice

5. **Write the proposal** to `.codebase-rizz/proposed/personas/<username>-YYYY-MM-DD.md`, using the same schema as the persona file itself so the human can easily merge sections. Only include *additions*, not the full file — the human appends.

## Why proposals, not direct edits

Personas describe real people. Getting a rule wrong is worse than missing one — a mischaracterized engineer makes the whole skill feel off. Proposals give the human a filter: does this actually sound like me? Would I flag this in review? If no, drop it.

## Cross-subskill dependency

`track/assign` and `track/reconcile` feed this subskill indirectly. When the ownership log says "Minh is building the CRM quick actions," and Minh's PR on that feature merges, this subskill should weight observations from that PR more heavily — they represent intentional design choices, not drive-by commits. Read `.codebase-rizz/feature-ownership.md` as context when processing a PR.

## What to report (manual invocation)

- For each persona: how many new PRs, how many new review comments, how many proposed additions (broken down by section)
- The paths to the proposal files
- A summary of which personas had the most growth

## Failure modes

- **A tracked username no longer exists** (engineer left the company, GitHub account renamed) — log a warning, skip that user, continue with the others
- **A persona file is missing for a tracked username** — the user probably removed the file but forgot to update config. Skip and warn
- **gh rate limit mid-run** — save partial progress, update the last-run timestamp only for users who completed, resume on next run
