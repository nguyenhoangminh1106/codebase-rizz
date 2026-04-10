# rizz.config.json schema

Every repo that uses codebase-rizz has one of these at `<data_dir>/rizz.config.json`, where `<data_dir>` is resolved via the registry lookup in `paths.md`. It's the single source of truth for which repo this is, which engineers to track, and when the crons run.

The file lives inside the repo's data directory regardless of storage mode — in global mode that's `~/.codebase-rizz/repos/<slug>/rizz.config.json`, and in repo-local mode it's `<repo-root>/.codebase-rizz/rizz.config.json`. The format is identical either way.

## Shape

```json
{
  "repo": "paraform-xyz/paraform",
  "default_branch": "main",
  "personas": ["minh2", "anthnykr", "taneliang", "owen-paraform"],
  "trusted_reviewers": ["anthnykr", "taneliang", "owen-paraform", "minhpg"],
  "crons": {
    "from_pr_comments": "0 6 * * *",
    "from_persona_code": "15 6 * * *",
    "track_reconcile": "0 7 * * *",
    "from_codebase": "0 9 * * 0",
    "patterns_drift": "30 9 * * 0"
  },
  "ignore_paths": [
    "lib/generated/**",
    "**/*.lock",
    "**/node_modules/**"
  ],
  "min_pr_comment_signal": 2
}
```

## Fields

- **`repo`** (required) — `owner/name` slug, used by every `gh` call
- **`default_branch`** (required) — branch name the crons target for "merged since yesterday" queries
- **`personas`** (required) — list of GitHub usernames this repo tracks. Every entry must have a corresponding file under `personas/`. `bootstrap` adds entries here; `learn/from-persona-code` reads it to know whose PRs to scrape
- **`trusted_reviewers`** (required for `from-pr-comments`) — allowlist of GitHub usernames whose review comments the skill is allowed to learn from. `from-pr-comments` reads this and silently drops comments from anyone not on the list. Typically a subset of senior reviewers the team trusts to give high-signal feedback. Leaving this empty disables `from-pr-comments` entirely (by design — an unconfigured allowlist is not permission to learn from everyone)
- **`crons`** — cron expressions in standard 5-field format (min hour dom mon dow). The `schedule` skill consumes these. All are optional — omit any cron to disable it
- **`ignore_paths`** — glob patterns of files the learning crons should not read. Generated code, lockfiles, and vendored deps add noise to pattern extraction
- **`min_pr_comment_signal`** — how many times a review comment theme must appear across recent PRs before `learn/from-pr-comments` proposes it as a pattern. Default 2. Higher = fewer, higher-confidence proposals

## Cron key → subskill mapping

| Config key | Subskill |
|---|---|
| `from_pr_comments` | `learn/from-pr-comments` |
| `from_persona_code` | `learn/from-persona-code` |
| `track_reconcile` | `track/reconcile` |
| `from_codebase` | `learn/from-codebase` |
| `patterns_drift` | `learn/patterns-drift` |

If a key is missing from `crons`, the scheduler does not register it. A user who only wants the review subskill and no learning loop can set `crons: {}`.

## Validation

Before any subskill uses this file, validate it. Missing `repo` is fatal. Missing `personas` is a warning — `code-like-auto` can still work if personas exist as files, but `from-persona-code` won't know who to scrape. Invalid cron expressions should be reported but not block the current run.
