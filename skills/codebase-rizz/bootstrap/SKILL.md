---
name: codebase-rizz-bootstrap
description: First-run setup for codebase-rizz in a new repo. Creates .codebase-rizz/, verifies gh CLI access, asks for tracked engineers by GitHub username, and seeds initial persona files by analyzing each engineer's recent merged PRs. Use when the user is adopting codebase-rizz in a new codebase or adding engineers to an existing setup.
---

# bootstrap

First-run setup. Runs once per repo, and again any time the user adds a new engineer to track.

## What this subskill does

Four things, in order. Don't skip ahead.

1. Run the gh preflight (see `../references/gh-preflight.md`). If it fails, stop and relay the fix. Bootstrap can't do anything without working gh access.
2. Create `.codebase-rizz/` in the current repo root with the directory layout from the top-level SKILL.md, plus a starter `rizz.config.json`. Don't overwrite if the directory already exists — print what's there and ask whether the user wants to add an engineer instead.
3. Ask the user which GitHub usernames to track. Accept them as a space- or comma-separated list. Validate each by running `gh api users/<username>` and bail on the first 404 with a clear error.
4. For each valid username, fetch their last 20 merged PRs in the configured repo, read the diffs and the review comments they authored on others' PRs, and synthesize a first-draft persona file at `personas/<username>.md` following the schema in `../references/persona-schema.md`. Write these as real files, not proposals — the human can always edit them later, and starting from blank slate is worse than starting from a reasonable draft.

## Finding engineer PRs

Use this gh command pattern:

```bash
gh pr list --repo <owner>/<repo> --author <username> --state merged --limit 20 \
  --json number,title,url,mergedAt,files,additions,deletions
```

For review comments they left on *others'* PRs (these are the richest signal for persona voice):

```bash
gh api "repos/<owner>/<repo>/pulls/comments?per_page=100" \
  --paginate --jq '.[] | select(.user.login == "<username>")' \
  | head -200
```

Don't paginate forever. Cap at the most recent 200 review comments or the command takes too long.

## Drafting the persona file

For each engineer, synthesize a persona file with these sections populated:

- **Frontmatter** — `name` (username), `display_name` (from `gh api users/<username>`), `strengths` (infer from file paths they touch most — frontend, backend, infra, schema), `triggers` (verbs + nouns from their PR titles and review comments), `anti_triggers` (areas they rarely touch)
- **Mental model** — one paragraph. Derive from the shape of their PRs: do they do small surgical fixes or large refactors? Do their review comments focus on types, architecture, naming, performance?
- **Principles** — 3–5 rules, each with a reason and a PR or comment link. Pull these from their review comments first, their own PR descriptions second
- **Anti-patterns** — 2–3 things they explicitly pushed back on in review. Direct quotes with links are ideal
- **Example PRs** — 3–5 of their merged PRs that best represent their style. Pick for variety (different parts of the codebase) not volume
- **Notes from review comments** — direct quotes with links, 5–10 of the most characteristic ones

The bootstrap draft is a first pass. `learn/from-persona-code` will refine it over time via proposals.

## Updating rizz.config.json

Append new usernames to the `personas` array. Don't overwrite the whole file — a user might have customized `crons`, `ignore_paths`, or `min_pr_comment_signal` already.

## Adding to the global registry

After successful bootstrap, append the absolute repo path to `~/.claude/skills/codebase-rizz/registry.json`:

```json
{ "repos": ["/abs/path/to/this/repo", "/other/repo"] }
```

This is how the cron scheduler knows which repos to visit. If the file doesn't exist, create it.

## Reporting back

Tell the user exactly:
- Which files were created (list the paths)
- Which personas were seeded and from how many PRs each
- Any usernames that failed validation
- The next step: either run `review` on a diff, or let the crons start learning

Don't run any learning crons during bootstrap — the seed drafts are enough, and running crons immediately would write proposals before the user has even seen the initial drafts.
