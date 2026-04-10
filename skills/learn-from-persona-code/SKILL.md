---
name: codebase-rizz-learn-from-persona-code
description: For each tracked engineer, scan their recently merged PRs and propose updates to their persona file — new principles, new anti-patterns, new example PRs, new review quotes. Runs as a daily cron but can be invoked manually. Writes to <data_dir>/proposed/personas/. Never edits persona files directly.
---

# learn / from-persona-code

Daily cron. Keeps each persona file growing as the engineer writes more code. Complements `learn/from-pr-comments`: that one learns team-wide patterns, this one learns per-engineer voice.

## Before doing anything

Resolve `<data_dir>` for the current repo via the registry lookup in `../_shared/paths.md`. As a multi-repo cron, iterate the registry and resolve once per repo; skip non-bootstrapped repos with a warning.

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

4. **Synthesize the observations.** Only extract things that would make the *user of this skill* genuinely better at code quality or design when they come back later. Apply this test to every candidate observation before including it:

   > Would a mid-level engineer reading this learn something about architecture, data modeling, abstraction boundaries, state management, error handling, tradeoff reasoning, or design taste?

   If the answer is no, drop it — even if it's new and even if it's repeated across PRs. Trivial stuff is not worth the shelf space in the persona file.

   **Extract**:
   - Non-obvious architectural choices (chose a store over a ref, flattened a nested context, broke a service into a repo layer)
   - Tradeoff reasoning (picked A over B and said *why* — "refs couple unrelated features", "this would exhaust the connection pool")
   - Reusable design patterns the engineer clearly favors, with the reason behind them
   - Strong opinions expressed in review on someone else's design, where the opinion generalizes beyond the one PR
   - Anti-patterns this engineer catches that others miss

   **Skip**:
   - Naming conventions (camelCase vs snake_case, renaming a variable)
   - Formatting, whitespace, lint-fixable anything
   - Obvious typos or one-word clarifications
   - "Move this line up" / "extract this to a function" when the reason is just readability and there's no deeper principle
   - Boilerplate refactors (e.g. "switched map to reduce") without a design reason
   - Any observation that boils down to "the engineer knows the language well" — that's not persona signal, that's baseline competence

   When in doubt, skip. The persona file is a knowledge base for the user, not a comprehensive log of every opinion the engineer has ever expressed.

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
