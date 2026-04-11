---
name: bootstrap
description: First-run setup for codebase-rizz in a new repo. Asks whether to store knowledge globally (private, no repo footprint) or repo-local (committed, team-shared), creates the chosen data directory, verifies gh CLI access, asks for tracked engineers by GitHub username, and seeds initial persona files from each engineer's recent merged PRs. Use when the user is adopting codebase-rizz in a new codebase or adding engineers to an already-bootstrapped one.
---

# bootstrap

First-run setup. Runs once per repo, or again to add engineers to an already-bootstrapped repo.

## The six things this does, in order

Don't skip ahead. Each step gates the next.

1. **Confirm we're in a git repo.** Run `git rev-parse --show-toplevel`. If it fails, stop and tell the user to `cd` into their project.
2. **Check the registry.** Read `~/.codebase-rizz/registry.json`. If it doesn't exist, tell the user to run `install.sh` first — bootstrap can't operate without the global data directory in place.
3. **Decide: new bootstrap or add-to-existing?** If the current repo path already appears in the registry, skip to step 6 (add engineers). Otherwise continue.
4. **Ask the user where to store this repo's knowledge.** See "The storage choice" below. Resolve to a `data_dir` path.
5. **Run the gh preflight.** See `../_shared/gh-preflight.md`. If it fails, stop and relay the fix — bootstrap can't seed personas without gh access.
6. **Ask which engineers to track**, validate each GitHub username, seed their persona files, and write `rizz.config.json`.

## The storage choice

Present this prompt verbatim (or very close — the structure matters more than the wording):

> Where should I store this project's codebase-rizz knowledge?
>
> **1) Global** (private to you, no footprint in the repo)
>   - Files live at `~/.codebase-rizz/repos/<slug>/`
>   - Nothing gets added to the repo's working tree or git history
>   - Good for: solo use, experimenting, projects where the team hasn't adopted codebase-rizz yet
>
> **2) Repo-local** (committed, shared with your team via git)
>   - Files live at `<repo-root>/.codebase-rizz/`
>   - Commit them so teammates get the same personas and patterns
>   - Good for: teams who've agreed to share institutional knowledge through version control
>
> Pick 1 or 2:

If the user picks **global**:
- Derive the slug from `git config --get remote.origin.url` using the algorithm in `../_shared/paths.md`
- `data_dir = ~/.codebase-rizz/repos/<slug>`
- `mkdir -p` the data dir and its subdirectories (`personas/`, `articles/`, `proposed/patterns/`, `proposed/personas/`)

If the user picks **repo-local**:
- `data_dir = <repo-root>/.codebase-rizz`
- `mkdir -p` the data dir and subdirectories
- Append `.codebase-rizz/proposed/` to `.gitignore` (create `.gitignore` if it doesn't exist). Append `.codebase-rizz/` itself is NOT added to gitignore — most of the dir is meant to be committed
- Tell the user explicitly: "I've added `.codebase-rizz/proposed/` to `.gitignore`. The rest of `.codebase-rizz/` is meant to be committed — commit it when you're ready."

If the repo has no remote (fresh `git init`), fall back to `local-<parent-dir-name>` as the slug and warn the user that remote-less slugs can become fragile if they add a remote later.

## Register the repo

After creating the data dir, append an entry to `~/.codebase-rizz/registry.json`:

```json
{
  "path": "<absolute repo path from git rev-parse --show-toplevel>",
  "slug": "<derived slug>",
  "remote_url": "<from git config --get remote.origin.url, or null>",
  "storage": "global" | "repo-local",
  "data_dir": "<resolved absolute path>",
  "bootstrapped_at": "<ISO 8601 UTC timestamp>"
}
```

Read the existing JSON, append to `repos`, write back. Never overwrite the whole file blindly — another repo's entry might already be there.

## Seed rizz.config.json

Create `<data_dir>/rizz.config.json` with sensible defaults. See `../_shared/config-schema.md` for the full shape. At minimum:

```json
{
  "version": 3,
  "repo": "<owner/name from remote URL>",
  "default_branch": "<from `git symbolic-ref refs/remotes/origin/HEAD` or prompt>",
  "personas": [],
  "trusted_reviewers": [],
  "crons": {
    "from_pr_comments": "0 6 * * *",
    "from_persona_code": "15 6 * * *",
    "track_reconcile": "0 7 * * *",
    "from_codebase": "0 9 * * 0",
    "patterns_drift": "30 9 * * 0",
    "auto_review": "0 10 * * 0"
  },
  "auto_review": {
    "mode": "off",
    "max_merges_per_run": 5
  },
  "ignore_paths": [],
  "min_pr_comment_signal": 2
}
```

The `version` field matches the highest version in `CHANGELOG.md` at the time bootstrap runs. The `upgrade` subskill uses this field to know which migrations to apply on future version bumps. Bootstrap always writes the current version; never write an older version even if you're seeding from an old template.

Fill `personas` in step 6 as the user names engineers. After that, ask separately: "Which of these engineers do you trust to produce high-signal review comments? These are the reviewers `learn/from-pr-comments` will learn team patterns from — usually the senior folks whose taste you'd want codified. Pick any subset, or leave empty to disable pattern learning." Fill `trusted_reviewers` with the answer.

## Seed persona files from real PRs

Ask the user which GitHub usernames to track (space- or comma-separated). For each:

1. **Validate**: `gh api users/<username>` — bail with a clear error on 404
2. **Fetch their last 20 merged PRs** in this repo:
   ```bash
   gh pr list --repo <owner>/<repo> --author <username> --state merged --limit 20 \
     --json number,title,url,mergedAt,files,additions,deletions
   ```
3. **Fetch up to 200 of their review comments on other people's PRs** (the richest signal for persona voice):
   ```bash
   gh api "repos/<owner>/<repo>/pulls/comments?per_page=100" --paginate \
     --jq '.[] | select(.user.login == "<username>")' | head -200
   ```
4. **Synthesize a first-draft persona file** at `<data_dir>/personas/<username>.md`, following the schema in `../_shared/persona-schema.md`. Populate:
   - Frontmatter (`name`, `display_name`, `strengths`, `triggers`, `anti_triggers`)
   - Mental model paragraph (derived from the shape of their PRs and the tone of their review comments)
   - 3–5 principles with PR links
   - 2–3 anti-patterns with PR links
   - 3–5 example PRs
   - 5–10 direct review quotes with links
5. **Append the username** to `personas` in `rizz.config.json`

The first draft is a starting point. `learn/from-persona-code` will refine it over time via proposals that the user merges.

## Install the cron agents

After personas are seeded, offer to install launchd cron agents:

> Want me to set up the learning crons now? These run on your local machine via launchd (macOS). I'll generate the plist files and print the commands for you to load them. Skip this and you can run the subskills manually or set them up later. (y/n)

If **yes**:

1. **Check the OS**. If not macOS, print: "Cron auto-install is macOS-only in v3. You can still run the subskills manually. On Linux/Windows, you'll need to set up your own scheduler pointing at `claude -p '/codebase-rizz:<skill-name>' --permission-mode dontAsk`." Skip the cron step and continue.
2. **Install the permissions allowlist** — see "Install the permissions allowlist" section below. This must happen BEFORE writing plists, because crons without permissions will silently auto-deny everything.
3. **Generate one plist per entry** in `rizz.config.json.crons` following the template in `../_shared/crons.md`. Use the slug from the registry entry for the label and file name. Write each plist to `~/Library/LaunchAgents/com.codebase-rizz.<slug>.<cron-key>.plist`. The plist's command line includes `--permission-mode dontAsk` — this is non-negotiable, the cron will not work without it.
4. **Create the log directory**: `mkdir -p ~/.codebase-rizz/logs/<slug>`
5. **Print the exact `launchctl load` commands** for every plist generated — don't run them automatically, let the user paste. Also print the `launchctl list | grep codebase-rizz` command so they can verify.

Bootstrap does not run any cron immediately. The seed drafts are enough; running crons on first bootstrap would write proposals before the user has even seen the initial personas. The first actual cron fires on its next scheduled slot.

### Install the permissions allowlist

Before generating any plists, walk the user through installing the headless-mode allowlist in `~/.claude/settings.json`. Without this, scheduled crons produce zero useful output — Claude auto-denies every `gh` call and every `~/.codebase-rizz/` write because there's no one to approve tool prompts in a non-interactive session.

1. **Read the full allowlist** from `../_shared/permissions.md`. That file is the single source of truth for which rules the crons need. Copy the `allow` array verbatim
2. **Read the user's existing `~/.claude/settings.json`** if it exists. Preserve every field that isn't `permissions.allow`. If the file doesn't exist, create a new one with only a `permissions` block
3. **Merge the allowlist** — add every rule from `permissions.md` that isn't already in the user's existing `permissions.allow` array. Don't duplicate rules the user has added themselves. Preserve any existing rules unrelated to codebase-rizz
4. **Check `permissions.defaultMode`** — if it's missing or already set to `dontAsk`, leave it. If it's set to something else (like `acceptEdits`), warn the user: "Your existing defaultMode is `<X>`. I won't override it — but note that scheduled crons pass `--permission-mode dontAsk` on the command line, which takes precedence at runtime."
5. **Show the user the proposed final state of the file** and ask for explicit confirmation:

   > I'm about to update `~/.claude/settings.json` with the allowlist needed for scheduled crons to work. Here's what the merged file will look like:
   >
   > ```json
   > { ... pretty-printed final state ... }
   > ```
   >
   > Write this to `~/.claude/settings.json`? (y/n)

6. **On `y`**, atomic-write the file (temp + rename) so a crash mid-write doesn't corrupt the user's global settings. On `n`, skip and warn: "Without the allowlist, your scheduled crons will not produce output. You can add the rules manually later — see `~/.claude/plugins/codebase-rizz/skills/_shared/permissions.md` for the full list."
7. **Do not proceed to plist generation if the user declined.** Print a clear message: "Skipping plist install. Re-run `/codebase-rizz:bootstrap` once you're ready to install both the allowlist and the crons together."

## Opt in to auto-review (optional, off by default)

After the learn crons are generated (or skipped), offer the auto-review opt-in:

> **Auto-review proposals?**
>
> codebase-rizz can run a separate weekly cron that reads each proposal, has Claude decide whether it's good enough to merge into `patterns.md` and the persona files, and actually does the merge for you. Clearly-bad items get rejected automatically. Ambiguous items stay in `proposed/` for you to review by hand.
>
> This is the only part of the skill that modifies your knowledge base without direct approval each time. Every decision is logged and reversible via `rollback`. It's **off by default** — most users start with `off` and run the learn crons for a week or two first to see what the proposals look like before enabling this.
>
> - 1) **Off** (recommended for new users — review everything manually)
> - 2) **Dry-run** (Claude decides but writes to a log instead of merging — good for building trust)
> - 3) **On** (Claude actually merges qualifying proposals)

Based on the answer:

- **Off** → set `auto_review.mode` to `"off"` in `rizz.config.json`. Do NOT generate the `auto_review` launchd plist. The cron key stays in `crons` for later opt-in but no agent is installed
- **Dry-run** → set `auto_review.mode` to `"dry_run"`. Generate the launchd plist for `auto_review` and print the `launchctl load` command alongside the learn-cron load commands
- **On** → set `auto_review.mode` to `"on"`. Generate plist, print load command. Warn the user: "Auto-review is now set to actually merge proposals. Review `<data_dir>/proposed/.auto-review-log` after the first run (Sunday 10am) and use `rollback` if Claude makes a bad call"

Default `auto_review.max_merges_per_run` to `5`. The user can raise it in config later if they trust the cron more.

## Set up notifications (optional)

After the auto-review step (whether it ran or was skipped), offer notification setup:

> Want to set up notifications for new proposals and articles? I can send them via Gmail or Slack. (y/n)

If **yes**, tell the user to run `/codebase-rizz:share-setup` as their next step. Bootstrap does not run share-setup in-place — skills in this plugin are independently invokable, not chained. Include the exact command in the final bootstrap report so the user can copy-paste it.

If **no**, continue. The user can run `/codebase-rizz:share-setup` later any time.

## Reporting back

Tell the user exactly:
- Which storage mode was chosen and where `data_dir` is
- Which files were created (list absolute paths)
- Which personas were seeded and how many PRs each was based on
- Any usernames that failed validation
- Which cron agents were generated (and the exact `launchctl load` commands to run)
- Whether notifications were set up, and if so, which channels/recipients
- A one-liner on what to try next: `review` on a diff, or asking for "code like <name>"
- If the repo has a long history (more than a few months of merged PRs), suggest running `/codebase-rizz:backfill` once to seed patterns and persona updates from historical PRs: "Your codebase has significant history. Run `/codebase-rizz:backfill` when you're ready to seed the knowledge base from past PRs — it's a one-time operation and takes a few minutes."

If repo-local storage was chosen, remind them one more time to commit the new files when they're ready.

## Edge cases

- **Already bootstrapped, user wants to add engineers**: skip the storage prompt, find the existing entry in the registry, append new usernames to the existing `personas` array and seed only the new files
- **Already bootstrapped, user wants to change storage mode**: don't do it here. Tell them to run `migrate` instead — it handles moving files atomically
- **User picks a username already in `personas`**: warn and skip; their existing file is authoritative
