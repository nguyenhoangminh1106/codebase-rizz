# Permissions for headless runs

Scheduled crons in codebase-rizz run via `claude -p "..."` — Claude Code's headless mode. Headless mode has **no one to answer permission prompts**, so every tool call must be pre-approved. Without a proper allowlist, crons will silently auto-deny every `gh` call and `~/.codebase-rizz/` write, producing empty output forever.

This file is the single source of truth for the allowlist. `bootstrap` writes these rules to `~/.claude/settings.json` during the cron install step, and `_shared/crons.md`'s plist template uses `--permission-mode allowAll` to enforce them. If you add a new shell command to any skill, add it here first.

## The rules

Add this block to the user's `~/.claude/settings.json` (merge with any existing `permissions.allow` array rather than clobbering):

```json
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Bash(gh auth status)",
      "Bash(gh auth status:*)",
      "Bash(gh repo view:*)",
      "Bash(gh api users/*:*)",
      "Bash(gh api repos/*:*)",
      "Bash(gh api:*)",
      "Bash(gh pr list:*)",
      "Bash(gh pr view:*)",
      "Bash(git rev-parse:*)",
      "Bash(git config:*)",
      "Bash(git symbolic-ref:*)",
      "Bash(git log:*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(launchctl load:*)",
      "Bash(launchctl unload:*)",
      "Bash(launchctl list:*)",
      "Bash(touch /tmp/codebase-rizz-gh-check-*)",
      "Bash(mkdir -p ~/.codebase-rizz/*)",
      "Bash(mkdir -p ~/Library/LaunchAgents)",
      "Read(~/.codebase-rizz/**)",
      "Write(~/.codebase-rizz/**)",
      "Edit(~/.codebase-rizz/**)",
      "Read(**/.codebase-rizz/**)",
      "Write(**/.codebase-rizz/**)",
      "Edit(**/.codebase-rizz/**)",
      "Read(~/Library/LaunchAgents/com.codebase-rizz.*.plist)",
      "Write(~/Library/LaunchAgents/com.codebase-rizz.*.plist)"
    ]
  }
}
```

## Why each rule

Grouped by what the skills actually do.

### gh preflight (`_shared/gh-preflight.md`)

- `Bash(gh auth status)` / `Bash(gh auth status:*)` — check if the user is logged in. Used by every skill that touches gh before any other gh call
- `Bash(gh repo view:*)` — check the repo slug from `rizz.config.json` is accessible
- `Bash(touch /tmp/codebase-rizz-gh-check-*)` — write the per-session cache marker so the preflight only runs once

### Learn crons (fetching PRs and comments)

- `Bash(gh pr list:*)` — used by `learn-from-pr-comments`, `learn-from-persona-code`, `backfill`, `track-reconcile` to list merged PRs in a window or by author
- `Bash(gh pr view:*)` — used occasionally to fetch a single PR's body or metadata
- `Bash(gh api repos/*:*)` — fetch review comments via `repos/<repo>/pulls/<number>/comments`
- `Bash(gh api users/*:*)` — validate GitHub usernames during bootstrap
- `Bash(gh api:*)` — catch-all for any other gh api call we might add later

### Path resolution and slug derivation (`_shared/paths.md`)

- `Bash(git rev-parse:*)` — `git rev-parse --show-toplevel` to find the repo root during the preflight
- `Bash(git config:*)` — `git config --get remote.origin.url` for slug derivation
- `Bash(git symbolic-ref:*)` — used by bootstrap to detect the default branch

### Read operations (various skills)

- `Bash(git log:*)` — used by `learn-patterns-drift` to scan recent merges for pattern violations
- `Bash(git status:*)` / `Bash(git diff:*)` — used by `review` to find the diff to review

### Cron install (`_shared/crons.md`)

- `Bash(launchctl load:*)` / `Bash(launchctl unload:*)` / `Bash(launchctl list:*)` — loading and querying scheduled agents
- `Bash(mkdir -p ~/Library/LaunchAgents)` — creating the agents dir if missing

### Data directory access (every skill)

- `Read(~/.codebase-rizz/**)` / `Write(~/.codebase-rizz/**)` / `Edit(~/.codebase-rizz/**)` — global storage mode
- `Read(**/.codebase-rizz/**)` / `Write(**/.codebase-rizz/**)` / `Edit(**/.codebase-rizz/**)` — repo-local storage mode. The `**/.codebase-rizz/**` glob is overbroad on purpose — `.codebase-rizz/` is a name we control, so any directory with that name in any project is presumptively ours

### Launchd plists

- `Read(~/Library/LaunchAgents/com.codebase-rizz.*.plist)` — bootstrap reads existing plists to know what's already installed
- `Write(~/Library/LaunchAgents/com.codebase-rizz.*.plist)` — bootstrap writes new plists when installing crons

Note the `com.codebase-rizz.*` pattern — we only write plists with this label prefix. Other launchd agents are untouched.

## What's intentionally NOT in the allowlist

Things we could have added but didn't, to keep the blast radius small:

- **`Bash(*)`** — would trust every shell command. Too broad; a compromised skill file could do anything
- **`Read`/`Write`/`Edit`** without a path qualifier — would trust any file read/write. Anyone with the allowlist loaded could read ssh keys or overwrite the shell profile
- **`Bash(rm *)`** — no rm patterns at all. We use file renames and overwrites, never `rm`. If a skill starts needing `rm`, add a narrow pattern like `Bash(rm ~/.codebase-rizz/proposed/*)` rather than broad access
- **`Bash(npm *)` / `Bash(yarn *)` / `Bash(curl *)`** — we don't run any package managers or network calls from scheduled crons. If we ever do, we'll add specific rules then
- **`Bash(claude *)`** — we don't invoke nested Claude sessions from inside a scheduled run. The launchd entry point is already `claude -p`, so a nested call would be a loop

## When to update this file

Add new entries whenever:

- A skill starts shelling out to a command we haven't used before
- A new gh endpoint gets called
- A new file path pattern gets read or written
- A new scheduled mechanism (beyond launchd) gets added

When you update this file, also update `bootstrap/SKILL.md` so existing users who re-run bootstrap get the new rules merged into their settings.json.

## Applying the rules

The allowlist has two deployment paths:

**1. Global `~/.claude/settings.json`** (recommended) — bootstrap writes these rules there, and every `claude -p` session (scheduled or interactive) inherits them. This is the path the skill uses by default.

**2. Per-command flags** — for one-off invocations, the exact rules can be passed as `--allowedTools "rule1" "rule2"` on the `claude -p` command line. `_shared/crons.md`'s plist template does NOT use this path because the list is long and would bloat the plist. Settings.json is cleaner.

Both paths are official and documented in the Claude Code permissions docs. The crons rely on settings.json being configured correctly.
