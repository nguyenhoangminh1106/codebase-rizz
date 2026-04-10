---
name: codebase-rizz-learn-from-pr-comments
description: Scrape merged PR review comments from the configured repo, cluster recurring themes, and propose new patterns for patterns.md. Runs as a daily cron but can be invoked manually. Writes proposals to <data_dir>/proposed/patterns/ — never edits patterns.md directly. Human merges.
---

# learn / from-pr-comments

Daily cron. Reads the recent review comments on merged PRs, finds themes that recur, and proposes new or updated patterns.

## Before doing anything

Resolve `<data_dir>` for the current repo via the registry lookup in `../../references/paths.md`. When this subskill runs as a cron across multiple repos, iterate the registry and resolve once per repo. If a repo's lookup fails (never bootstrapped), skip it with a warning.

## Schedule

Default: daily at 6:00am. Configured via `crons.from_pr_comments` in `rizz.config.json`. Registered with the `schedule` skill during bootstrap.

## What "recent" means

Since the last successful run of this cron. Track the last-run timestamp at `<data_dir>/proposed/.from-pr-comments-last-run`. If the file doesn't exist, default to "PRs merged in the last 24 hours."

## The pipeline

1. **Fetch merged PRs** in the window:
   ```bash
   gh pr list --repo <repo> --state merged --search "merged:>=<last_run>" \
     --json number,title,url,author,mergedAt --limit 100
   ```

2. **Fetch review comments** for each PR, restricted to the trusted reviewer allowlist:
   ```bash
   gh api "repos/<repo>/pulls/<number>/comments" --paginate \
     --jq '.[] | {user: .user.login, body: .body, path: .path, line: .line, html_url: .html_url}'
   ```
   Then filter the results:
   - **Keep only comments from usernames in `trusted_reviewers`** (read from `<data_dir>/rizz.config.json`). If `trusted_reviewers` is empty or missing, stop the entire run and tell the user to configure it — this cron must never learn from an uncurated firehose
   - Drop anything with `[bot]` in the username as a belt-and-suspenders check, even if a bot somehow ended up on the allowlist
   - Drop comments shorter than 20 characters (usually "lgtm" or emoji)

3. **Cluster themes**. For each comment, extract the underlying principle — not the specific fix, but the general rule. "You should use `findUnique` here" becomes "prefer findUnique over findFirst when querying a unique key." Group similar principles across comments.

4. **Apply the signal threshold**. Read `min_pr_comment_signal` from `rizz.config.json` (default 2). A theme needs at least that many distinct source comments to qualify as a proposal. This is the noise filter — a one-off comment isn't a pattern.

5. **Check against existing patterns**. Read `<data_dir>/patterns.md`. If a theme already exists there, don't propose a duplicate — but do propose an *amendment* if the new comments add a nuance or an edge case the existing pattern missed.

6. **Write the proposal** to `<data_dir>/proposed/patterns/YYYY-MM-DD.md`:

   ```markdown
   # Proposed patterns — 2026-04-11

   ## New pattern candidate: Prefer findUnique over findFirst for unique keys
   **Why**: findFirst implies multiple matches are possible. findUnique signals intent (exactly one row) and is clearer at the call site.
   **Evidence** (3 comments):
   - PR #8865, owen-paraform: "this should be a findunique" — [link]
   - PR #XXXX, anthnykr: "…" — [link]
   - PR #XXXX, …

   ## Amendment to existing pattern #7: All Prisma calls belong in repositories
   **Addition**: Also applies to `read_only_prisma`, not just the main client. Several recent PRs missed this.
   **Evidence** (2 comments):
   - PR #XXXX, …
   ```

7. **Update the last-run timestamp** only after writing the proposal file successfully.

## Constraints

- **Never edit `patterns.md` directly.** Proposals only. The human merges manually — usually by reviewing the proposal file, deciding which to accept, and editing `patterns.md` themselves. This preserves the signal-to-noise ratio and keeps the skill from self-poisoning on bad comments.
- **Don't propose things that are just language-specific style.** "Use const instead of let" isn't a team pattern, it's a linter rule. Focus on architectural, domain, and review-taste signals.
- **Don't propose patterns derived from a single engineer's comments.** Persona-specific taste goes in `learn/from-persona-code`, not here. A true team pattern shows up in comments from multiple reviewers.

## What to report back (when run manually)

- How many PRs were scanned and the date range
- How many comments passed the noise filter
- How many new patterns proposed, how many amendments
- The path to the proposal file
- A one-line hint: "review it and merge into patterns.md when you're happy"

## Failure modes

- **`trusted_reviewers` missing or empty in config** — stop the run, tell the user to add at least one username to `trusted_reviewers` in `rizz.config.json`, do not update the last-run timestamp. This is intentional: an unconfigured allowlist means the cron has no authority to learn from anyone, and the right fix is always a config change, never a silent fallback
- **gh rate limit** — bail gracefully, don't update the last-run timestamp, the next run will pick up where this one left off
- **No new PRs** — touch the last-run timestamp, write a proposal file with just a "nothing to propose" line, return
- **`patterns.md` missing** — tell the user to run `bootstrap` first, don't auto-create
