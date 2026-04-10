---
name: codebase-rizz-bootstrap
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
5. **Run the gh preflight.** See `../references/gh-preflight.md`. If it fails, stop and relay the fix — bootstrap can't seed personas without gh access.
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
- Derive the slug from `git config --get remote.origin.url` using the algorithm in `../references/paths.md`
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

Create `<data_dir>/rizz.config.json` with sensible defaults. See `../references/config-schema.md` for the full shape. At minimum:

```json
{
  "repo": "<owner/name from remote URL>",
  "default_branch": "<from `git symbolic-ref refs/remotes/origin/HEAD` or prompt>",
  "personas": [],
  "crons": {
    "from_pr_comments": "0 6 * * *",
    "from_persona_code": "15 6 * * *",
    "track_reconcile": "0 7 * * *",
    "from_codebase": "0 9 * * 0",
    "patterns_drift": "30 9 * * 0"
  },
  "ignore_paths": [],
  "min_pr_comment_signal": 2
}
```

Fill `personas` in step 6 as the user names engineers.

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
4. **Synthesize a first-draft persona file** at `<data_dir>/personas/<username>.md`, following the schema in `../references/persona-schema.md`. Populate:
   - Frontmatter (`name`, `display_name`, `strengths`, `triggers`, `anti_triggers`)
   - Mental model paragraph (derived from the shape of their PRs and the tone of their review comments)
   - 3–5 principles with PR links
   - 2–3 anti-patterns with PR links
   - 3–5 example PRs
   - 5–10 direct review quotes with links
5. **Append the username** to `personas` in `rizz.config.json`

The first draft is a starting point. `learn/from-persona-code` will refine it over time via proposals that the user merges.

## Don't run crons yet

Bootstrap does not kick off any learning crons. The seed drafts are enough; running crons immediately would write proposals before the user has even seen the initial personas. The user (or the `schedule` skill) starts crons when they're ready.

## Reporting back

Tell the user exactly:
- Which storage mode was chosen and where `data_dir` is
- Which files were created (list absolute paths)
- Which personas were seeded and how many PRs each was based on
- Any usernames that failed validation
- A one-liner on what to try next: `review` on a diff, or asking for "code like <name>"

If repo-local storage was chosen, remind them one more time to commit the new files when they're ready.

## Edge cases

- **Already bootstrapped, user wants to add engineers**: skip the storage prompt, find the existing entry in the registry, append new usernames to the existing `personas` array and seed only the new files
- **Already bootstrapped, user wants to change storage mode**: don't do it here. Tell them to run `migrate` instead — it handles moving files atomically
- **User picks a username already in `personas`**: warn and skip; their existing file is authoritative
