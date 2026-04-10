# codebase-rizz

A Claude Code plugin that learns any codebase's lived wisdom — who codes how, what patterns the team cares about, how features actually get built — then uses that knowledge to generate, review, and teach.

## What it does

Every codebase has two layers of knowledge. The first is the code itself — files, tests, types. Any agent can read that. The second is the *why*: why did this engineer reach for a store instead of a ref, why does that one always use `satisfies` instead of `as const`, why did the team decide eligibility checks must not mix concerns. That second layer lives in people's heads and in scattered PR comments, and it's what `codebase-rizz` exists to capture.

## Features

- **Generate code in a specific engineer's style.** "Write this the way Minh would." Personas are learned from real merged PRs and review comments, not hardcoded
- **Self-review against team patterns.** Checks a diff against `patterns.md` — the team's accumulated review rulebook — before you open a PR
- **Learn every day.** Daily and weekly crons scrape recent PRs and propose new patterns, persona updates, and long-form articles about how features work. Human merges all proposals (or opt into auto-review for the clearly-good ones)
- **Narrative articles from real code.** Weekly cron picks one un-documented feature, researches its PRs and review threads, and writes a technical blog post grounded in real quotes and case studies
- **Track who's building what.** Lightweight ownership log that the skill uses as context for better persona matching and smarter suggestions
- **Backfill from history.** One-time seed of patterns and personas from past PRs, so mature codebases don't have to wait weeks for the daily crons to accumulate signal
- **Notifications to Gmail or Slack.** Optional. Uses the official Claude Slack app and Gmail MCP — emails send from *your* Gmail, Slack posts through the Claude app in your workspace. You pick which channels and events trigger them
- **Per-repo isolation.** Knowledge never crosses between codebases. Every repo has its own data directory — stored globally in your home dir by default, or committed inside the repo if your team wants to share
- **Scales to many projects.** One install, use across all your repos

## Install

The recommended way is installing via the Claude Code plugin system. It's a two-step process: add the marketplace, then install the plugin.

**Step 1 — Add the marketplace** (one-time):

```
/plugin marketplace add nguyenhoangminh1106/codebase-rizz
```

This tells Claude Code where to find the plugin. It reads the `.claude-plugin/marketplace.json` file at the root of this repo and registers the plugin. The marketplace is named `codebase-rizz` by default.

**Step 2 — Install the plugin**:

```
/plugin install codebase-rizz@codebase-rizz
```

The first `codebase-rizz` is the plugin name, the second is the marketplace name. This installs all 17 skills under the `/codebase-rizz:*` namespace. Your global data directory at `~/.codebase-rizz/` is created on first use by `/codebase-rizz:bootstrap`.

### Fallback: curl install

If you don't want to use the plugin/marketplace system, a fallback script is available. It copies the plugin into `~/.claude/plugins/codebase-rizz/` and creates the data directory:

```bash
curl -fsSL https://raw.githubusercontent.com/nguyenhoangminh1106/codebase-rizz/main/install.sh | bash
```

Re-running is safe — it upgrades the plugin code in place and never touches your data.

## Getting started

After installing, in any repo you want to track:

```
/codebase-rizz:bootstrap
```

Bootstrap will:
1. Ask where to store this project's knowledge (global or repo-local)
2. Verify `gh` CLI access
3. Ask for the GitHub usernames of the engineers you want to track
4. Ask which of those should be considered trusted reviewers (the ones whose PR comments the skill is allowed to learn from)
5. Seed a first-draft persona file for each by reading their recent merged PRs
6. Offer to install the local cron agents that do daily and weekly learning
7. Offer to opt into auto-review (off by default)
8. Offer to configure notifications (Gmail, Slack, or the markdown fallback)

If your codebase has a long history, run `/codebase-rizz:backfill` after bootstrap to seed patterns and personas from past PRs in one pass.

## Requirements

- **macOS** (v3 only — Linux and Windows support coming later)
- [GitHub CLI](https://cli.github.com/) (`gh`) with `repo` and `read:org` scopes
- [Claude Code](https://claude.com/claude-code)
- Optional: Gmail MCP and/or the Slack plugin if you want notifications (see `skills/_shared/mcp-install.md` after installing)

Crons run locally via **launchd user agents** (macOS native). Nothing runs in the cloud, no external scheduler needed — just your own machine on a schedule. See `skills/_shared/crons.md` in this repo for how the plists are generated and loaded.

## Where your knowledge lives

At bootstrap you pick one of two storage modes per project:

**Global (default)** — private to you, zero footprint in the repo

```
~/.codebase-rizz/
├── registry.json            # index of every repo you track
└── repos/
    └── <slug>/              # one dir per project
        ├── rizz.config.json
        ├── personas/
        ├── patterns.md
        ├── feature-ownership.md
        ├── articles/
        └── proposed/        # cron output awaiting human merge
```

**Repo-local** — committed with the code, shared with your team

```
<repo-root>/.codebase-rizz/
├── rizz.config.json
├── personas/
├── patterns.md
├── feature-ownership.md
├── articles/
└── proposed/                # gitignored
```

In repo-local mode, commit everything except `proposed/` — bootstrap adds the gitignore entry for you. You can switch modes later with `/codebase-rizz:migrate`.

The skill uses the same layout either way. Every skill resolves the current repo's data directory via `~/.codebase-rizz/registry.json`, so the choice is transparent to the rest of the plugin.

## Slash commands

Every capability is a separately invokable slash command under the `/codebase-rizz:*` namespace:

| Slash command | What it does |
|---|---|
| `/codebase-rizz:bootstrap` | First-run setup in a repo: storage mode, personas, trusted reviewers, cron install, notifications |
| `/codebase-rizz:backfill` | One-time seed of patterns and personas from historical PRs — run once after bootstrap on mature codebases |
| `/codebase-rizz:review` | Check a diff against `patterns.md` and the relevant persona's taste |
| `/codebase-rizz:code-like-auto` | Pick the best persona for a task and generate code in their voice |
| `/codebase-rizz:code-like-person` | Generate code in a named engineer's voice (call directly if you know who) |
| `/codebase-rizz:learn-from-pr-comments` | Manual run: scrape recent merged PR review comments for new team patterns (also runs as a daily cron) |
| `/codebase-rizz:learn-from-persona-code` | Manual run: scrape recent merged PRs per engineer for persona updates (also daily cron) |
| `/codebase-rizz:learn-from-codebase` | Pick one un-documented feature and write a narrative technical article about it (also weekly cron) |
| `/codebase-rizz:learn-patterns-drift` | Check whether patterns in `patterns.md` are being violated silently in merged code (also weekly cron) |
| `/codebase-rizz:learn-auto-review` | Opt-in: have Claude review pending proposals and merge the clearly-good ones (weekly cron, default off) |
| `/codebase-rizz:rollback` | Undo a recent auto-review merge via the audit log |
| `/codebase-rizz:track-assign` | Record that an engineer is building a feature |
| `/codebase-rizz:track-reconcile` | Verify ownership log against real PR activity (also daily cron) |
| `/codebase-rizz:migrate` | Move a repo's data between global and repo-local storage |
| `/codebase-rizz:share` | Send updates to Gmail/Slack (or a markdown fallback) via MCP |
| `/codebase-rizz:share-setup` | Interactive setup for notification channels, recipients, and events |
| `/codebase-rizz:upgrade` | Migrate an existing setup to a newer version of codebase-rizz without re-bootstrapping |

All learning crons write proposals — they never edit your knowledge files directly. You merge. The only exception is `learn-auto-review`, which is opt-in and logs every decision for rollback.

## Design principles

1. **Every learned thing is a proposal.** The skill never rewrites its own training data without human approval (except the opt-in auto-review cron, and only for proposals that pass a strict quality bar)
2. **Per-repo isolation.** One repo's personas don't bleed into another's
3. **Personas are data.** Adding an engineer is a new markdown file, not a code change
4. **Explain the why.** Every rule ships with the reason, usually linked to a PR comment
5. **Trusted reviewers only.** The skill never learns from an uncurated firehose — every team has to pick who counts as a high-signal reviewer before learning turns on

## Upgrading

To pull the latest version of the plugin:

```
/plugin marketplace update codebase-rizz
/plugin update codebase-rizz@codebase-rizz
```

Or, if you installed via the curl fallback, just re-run the install script. Either path is safe — plugin code is replaced in place and your data at `~/.codebase-rizz/` is untouched.

After upgrading, if the new version has new features to opt into, run:

```
/codebase-rizz:upgrade
```

from any tracked repo. Upgrade walks you through what's new version by version and lets you opt into each new feature per repo. Your existing config is preserved. Nothing is changed silently.

See [CHANGELOG.md](./CHANGELOG.md) for the list of versions and what changed.

## Layout of this repo

```
codebase-rizz/
├── plugin.json             # plugin manifest
├── README.md               # this file
├── LICENSE                 # MIT
├── CHANGELOG.md            # structured version history
├── install.sh              # fallback curl install path
└── skills/
    ├── bootstrap/SKILL.md
    ├── backfill/SKILL.md
    ├── review/SKILL.md
    ├── code-like-auto/SKILL.md
    ├── code-like-person/SKILL.md
    ├── learn-from-pr-comments/SKILL.md
    ├── learn-from-persona-code/SKILL.md
    ├── learn-from-codebase/SKILL.md
    ├── learn-patterns-drift/SKILL.md
    ├── learn-auto-review/SKILL.md
    ├── rollback/SKILL.md
    ├── track-assign/SKILL.md
    ├── track-reconcile/SKILL.md
    ├── migrate/SKILL.md
    ├── share/SKILL.md
    ├── share-setup/SKILL.md
    ├── upgrade/SKILL.md
    └── _shared/            # reference docs used by every skill
        ├── paths.md
        ├── gh-preflight.md
        ├── persona-schema.md
        ├── config-schema.md
        ├── crons.md
        └── mcp-install.md
```

Every `skills/<name>/SKILL.md` is an independently invokable slash command. The leading-underscore `_shared/` directory holds reference material the skills cite — it's not a slash command and won't show up in the UI.

## Status

Alpha. Scaffolded and ready for first users. Expect API evolution across versions — the `upgrade` subskill is the safety net for that.

## License

MIT
