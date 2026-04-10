# codebase-rizz

A Claude Code skill that learns any codebase's lived wisdom — who codes how, what patterns the team cares about, how features actually get built — then uses that knowledge to generate, review, and teach.

## What it does

Every codebase has two layers of knowledge. The first is the code itself — files, tests, types. Any agent can read that. The second is the *why*: why did this engineer reach for a store instead of a ref, why does that one always use `satisfies` instead of `as const`, why did the team decide eligibility checks must not mix concerns. That second layer lives in people's heads and in scattered PR comments, and it's what `codebase-rizz` exists to capture.

## Features

- **Generate code in a specific engineer's style.** "Write this the way Minh would." Personas are learned from real merged PRs and review comments, not hardcoded
- **Self-review against team patterns.** Checks a diff against `patterns.md` — the team's accumulated review rulebook — before you open a PR
- **Learn every day.** Daily and weekly crons scrape recent PRs and propose new patterns, persona updates, and long-form articles about how features work. Human merges all proposals
- **Track who's building what.** Lightweight ownership log that the skill uses as context for better persona matching and smarter suggestions
- **Notifications to Gmail or Slack.** Optional. Uses your own authenticated MCPs — emails send from *your* Gmail, Slack posts go through a bot *you* create in *your* workspace. You pick which channels and which events trigger them
- **Per-repo isolation.** Knowledge never crosses between codebases. Every repo has its own data directory — stored globally in your home dir by default, or committed inside the repo if your team wants to share
- **Scales to many projects.** One install, use across all your repos. Each project picks its own storage mode at bootstrap time

## Install

One line, no cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/nguyenhoangminh1106/codebase-rizz/main/install.sh | bash
```

This downloads the skill to `~/.claude/skills/codebase-rizz/` and creates the global data directory at `~/.codebase-rizz/`. Re-running is safe — it upgrades the skill in place and never touches your data.

Then in any repo you want to track, run:

```
/codebase-rizz bootstrap
```

Bootstrap will:
1. Ask where to store this project's knowledge (global or repo-local — see below)
2. Verify `gh` CLI access
3. Ask for the GitHub usernames of the engineers you want to track
4. Seed a first-draft persona file for each by reading their recent merged PRs

## Requirements

- **macOS** (v1 only — Linux and Windows support coming later)
- [GitHub CLI](https://cli.github.com/) (`gh`) with `repo` and `read:org` scopes
- [Claude Code](https://claude.com/claude-code)
- Optional: Gmail MCP and/or Slack MCP if you want notifications

Crons run locally via **launchd user agents** (macOS native). Nothing runs in the cloud, no external scheduler needed — just your own machine on a schedule. See `skills/codebase-rizz/references/crons.md` for how the plists are generated and loaded.

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

In repo-local mode, commit everything except `proposed/` — bootstrap adds the gitignore entry for you. You can switch modes later with the `migrate` subskill.

The skill uses the same layout either way. Every subskill resolves the current repo's data directory via `~/.codebase-rizz/registry.json`, so the choice is fully transparent to the rest of the skill.

## Subskills

| Subskill | What it does |
|---|---|
| `bootstrap` | First-run setup, persona seeding from GitHub |
| `generate/code-like-auto` | Pick the right persona for a task, then generate |
| `generate/code-like-auto/code-like-person` | Generate code in a named engineer's style |
| `review` | Check a diff against `patterns.md` and persona taste |
| `learn/from-pr-comments` | Daily cron — propose new team patterns |
| `learn/from-persona-code` | Daily cron — propose persona updates |
| `learn/from-codebase` | Weekly cron — write a technical article about one feature |
| `learn/patterns-drift` | Weekly cron — flag patterns being ignored |
| `track/assign` | Record that an engineer is building a feature |
| `track/reconcile` | Daily cron — verify ownership against real PR activity |
| `migrate` | Move a repo's data between global and repo-local storage |
| `share` | Send updates to Gmail/Slack (or a markdown fallback) via MCP |
| `share/setup` | Interactive setup for notification channels and recipients |

All learning crons write proposals — they never edit your knowledge files directly. You merge.

## Design principles

1. **Every learned thing is a proposal.** The skill never rewrites its own training data without human approval
2. **Per-repo isolation.** One repo's personas don't bleed into another's
3. **Personas are data.** Adding an engineer is a new markdown file, not a code change
4. **Explain the why.** Every rule ships with the reason, usually linked to a PR comment

## Status

Alpha. Scaffolded and ready for first users. See the SKILL.md files under `skills/codebase-rizz/` for full subskill documentation.

## License

MIT
