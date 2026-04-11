---
name: learn-from-persona-code
description: For each tracked engineer, scan their recently merged PRs and propose updates to their persona file — new principles, new anti-patterns, new example PRs, new review quotes. Runs as a daily cron but can be invoked manually. Writes to <data_dir>/proposed/personas/. Never edits persona files directly.
---

# learn / from-persona-code

Daily cron. Keeps each persona file growing as the engineer writes more code. Complements `learn/from-pr-comments`: that one learns team-wide patterns, this one learns per-engineer voice.

## Before doing anything

Run the preflight from `../_shared/paths.md` to resolve `<data_dir>`. As a multi-repo cron, iterate every registry entry and run the preflight per repo; skip non-bootstrapped repos with a warning.

## Schedule

Default: daily at 6:15am (15 min after `from-pr-comments` so the two don't contend for gh rate limit). Configured via `crons.from_persona_code` and loaded as a launchd user agent by bootstrap. See `../_shared/crons.md`.

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

3. **Compare against their existing persona file**. Read `<data_dir>/personas/<username>.md`. For each new observation, decide:
   - Is this a *new* principle not yet in the file? → propose as addition
   - Does it *sharpen* an existing principle (adding a condition or a counterexample)? → propose as amendment
   - Is it just a repeat of what's already there? → skip, don't noise up the proposal

4. **Apply the shared quality filter** from `../_shared/quality-filter.md` to every candidate observation. Only extract things that pass — the filter's transfer test, PASS/FAIL examples, and when-in-doubt-drop rule all live in that file.

   This skill has one additional lens on top of the shared filter: the observation should not just teach *code quality or design*, it should teach something specific to **this engineer's voice**. A rule that every senior engineer would agree with belongs in team patterns (`learn-from-pr-comments`), not in a persona. A persona addition should be something the user would nod at and say "yeah, that's how Minh thinks." If the observation is generic engineering wisdom, skip it — it's not wrong, it's just in the wrong file.

5. **Write the proposal** to `<data_dir>/proposed/personas/<username>-YYYY-MM-DD.md`, using the same schema as the persona file itself so the human can easily merge sections. Only include *additions*, not the full file — the human appends.

## Why proposals, not direct edits

Personas describe real people. Getting a rule wrong is worse than missing one — a mischaracterized engineer makes the whole skill feel off. Proposals give the human a filter: does this actually sound like me? Would I flag this in review? If no, drop it.

## Cross-subskill dependency

`track/assign` and `track/reconcile` feed this subskill indirectly. When the ownership log says "Minh is building the CRM quick actions," and Minh's PR on that feature merges, this subskill should weight observations from that PR more heavily — they represent intentional design choices, not drive-by commits. Read `<data_dir>/feature-ownership.md` as context when processing a PR.

## What to report (manual invocation)

- For each persona: how many new PRs, how many new review comments, how many proposed additions (broken down by section)
- The paths to the proposal files
- A summary of which personas had the most growth

## Failure modes

- **A tracked username no longer exists** (engineer left the company, GitHub account renamed) — log a warning, skip that user, continue with the others
- **A persona file is missing for a tracked username** — the user probably removed the file but forgot to update config. Skip and warn
- **gh rate limit mid-run** — save partial progress, update the last-run timestamp only for users who completed, resume on next run
