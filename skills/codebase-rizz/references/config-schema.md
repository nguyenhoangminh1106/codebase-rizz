# rizz.config.json schema

Every repo that uses codebase-rizz has one of these at `<data_dir>/rizz.config.json`, where `<data_dir>` is resolved via the registry lookup in `paths.md`. It's the single source of truth for which repo this is, which engineers to track, and when the crons run.

The file lives inside the repo's data directory regardless of storage mode — in global mode that's `~/.codebase-rizz/repos/<slug>/rizz.config.json`, and in repo-local mode it's `<repo-root>/.codebase-rizz/rizz.config.json`. The format is identical either way.

## Shape

```json
{
  "version": 2,
  "repo": "paraform-xyz/paraform",
  "default_branch": "main",
  "personas": ["minh2", "anthnykr", "taneliang", "owen-paraform"],
  "trusted_reviewers": ["anthnykr", "taneliang", "owen-paraform", "minhpg"],
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
  "ignore_paths": [
    "lib/generated/**",
    "**/*.lock",
    "**/node_modules/**"
  ],
  "min_pr_comment_signal": 2,
  "notifications": {
    "enabled": true,
    "channels": {
      "gmail": {
        "enabled": true,
        "recipients": ["team@company.com", "minh@company.com"]
      },
      "slack": {
        "enabled": true,
        "channels": ["#engineering", "#codebase-rizz"]
      }
    },
    "events": {
      "learn_proposals_ready": true,
      "new_article_published": true,
      "ownership_mismatch_detected": false
    }
  }
}
```

## Fields

- **`version`** (required, integer) — schema version of this config file. Bootstrap writes the current skill version (from `CHANGELOG.md`). The `upgrade` subskill uses this to know which migrations to run. A missing `version` field is treated as v1 for backward compatibility with configs written before the version field existed
- **`repo`** (required) — `owner/name` slug, used by every `gh` call
- **`default_branch`** (required) — branch name the crons target for "merged since yesterday" queries
- **`personas`** (required) — list of GitHub usernames this repo tracks. Every entry must have a corresponding file under `personas/`. `bootstrap` adds entries here; `learn/from-persona-code` reads it to know whose PRs to scrape
- **`trusted_reviewers`** (required for `from-pr-comments`) — allowlist of GitHub usernames whose review comments the skill is allowed to learn from. `from-pr-comments` reads this and silently drops comments from anyone not on the list. Typically a subset of senior reviewers the team trusts to give high-signal feedback. Leaving this empty disables `from-pr-comments` entirely (by design — an unconfigured allowlist is not permission to learn from everyone)
- **`crons`** — cron expressions in standard 5-field format (min hour dom mon dow). Bootstrap translates these into launchd plist files and loads them as user agents. All entries are optional — omit any cron to disable it
- **`ignore_paths`** — glob patterns of files the learning crons should not read. Generated code, lockfiles, and vendored deps add noise to pattern extraction
- **`min_pr_comment_signal`** — how many times a review comment theme must appear across recent PRs before `learn/from-pr-comments` proposes it as a pattern. Default 2. Higher = fewer, higher-confidence proposals
- **`notifications`** — optional. Configures the `share/` subskill that sends updates (new patterns, new articles, ownership mismatches) out to Gmail and/or Slack. If omitted or `enabled: false`, the skill writes a markdown fallback to `<data_dir>/shared/` that the user can copy-paste anywhere. See the "Notifications" section below for the full shape
- **`auto_review`** — optional. Opt-in configuration for the `learn/auto-review` cron that can actually merge proposals into `patterns.md` and persona files. **Off by default** — if this block is missing or `mode: "off"`, the auto-review cron never runs even if it's in the `crons` map. See "Auto-review" section below

## Cron key → subskill mapping

| Config key | Subskill |
|---|---|
| `from_pr_comments` | `learn/from-pr-comments` |
| `from_persona_code` | `learn/from-persona-code` |
| `track_reconcile` | `track/reconcile` |
| `from_codebase` | `learn/from-codebase` |
| `patterns_drift` | `learn/patterns-drift` |
| `auto_review` | `learn/auto-review` (opt-in only, see `auto_review.mode`) |

If a key is missing from `crons`, bootstrap does not generate a launchd agent for it. A user who only wants the review subskill and no learning loop can set `crons: {}`.

## Notifications

The `notifications` block is structured so every channel is opt-in independently and every event class can be toggled on or off.

- **`enabled`** — master switch. If false, the `share/` subskill does nothing (not even the markdown fallback). Set to false to quickly pause notifications without losing your config
- **`channels.gmail.enabled`** — whether to send via the Gmail MCP. Requires the user to have an authenticated Gmail MCP server accessible to the local Claude Code session. Emails are sent from the user's own authenticated Gmail address (there is no shared bot account)
- **`channels.gmail.recipients`** — list of email addresses to send to. Each recipient gets the same message. Empty or missing = Gmail channel is a no-op even if `enabled: true`
- **`channels.slack.enabled`** — whether to post via the Slack MCP. Requires the user to have created a Slack app in their workspace, authenticated the MCP, and granted it permission to post to the target channels. Messages are posted as the app/bot, not as the user
- **`channels.slack.channels`** — list of Slack channel names (with or without `#`) or user DMs to post to
- **`events`** — which classes of event trigger a send. Every subskill that wants to notify something reads the matching key and only proceeds if it's true. Adding a new event means adding both a new key here and respecting it in the subskill that fires the event

When a notification is sent, the `share/` subskill logs each delivery (per channel, per recipient, per event) to `<data_dir>/proposed/.notification-log` so failures don't get lost.

## Auto-review

`auto_review` is the only config block that grants a cron permission to modify knowledge files (`patterns.md` and `personas/*.md`). Every other learning cron is read-only on those files. Because of that, this block is off by default, opt-in, and has three modes:

- **`mode: "off"`** (default) — the `learn/auto-review` cron does nothing. Knowledge files are modified only by humans. This is the safe starting point for any new user
- **`mode: "dry_run"`** — the cron runs, reviews each proposal, and writes a log of what it *would* have merged to `<data_dir>/proposed/.auto-review-dry-run-YYYY-MM-DD.md`. It does NOT actually touch knowledge files or proposal files. Use this to build trust in Claude's judgment before giving it write access. Recommended for at least 2 weeks before flipping to `on`
- **`mode: "on"`** — the cron actually merges qualifying proposals into knowledge files, rejects noise, and leaves ambiguous items for human review. Every decision is recorded in `<data_dir>/proposed/.auto-review-log` and is reversible via the `rollback` subskill

- **`max_merges_per_run`** (default 5) — hard cap on how many merges can happen in a single cron run. If the cron wants to merge more than this, something is off (big proposal backlog, or over-eager Claude). Extra items stay in the proposal file for the next run or manual review

The auto-review subskill has its own internal quality bar beyond the user's config — every merge requires 3+ pieces of evidence, 2+ distinct trusted reviewers, a clear *why*, no duplication of existing rules, not an amendment to an existing rule, and high Claude confidence. Those criteria are hardcoded in the subskill to prevent users from accidentally loosening the bar via config.

## Validation

Before any subskill uses this file, validate it. Missing `repo` is fatal. Missing `personas` is a warning — `code-like-auto` can still work if personas exist as files, but `from-persona-code` won't know who to scrape. Invalid cron expressions should be reported but not block the current run. Missing or invalid `notifications` is treated as "no notifications configured" — not an error. Missing or invalid `auto_review` is treated as `mode: "off"` — not an error.
