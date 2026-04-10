# codebase-rizz

A Claude Code skill that learns any codebase's lived wisdom — who codes how, what patterns the team cares about, how features actually get built — then uses that knowledge to generate, review, and teach.

## What it does

Every codebase has two layers of knowledge. The first is the code itself — files, tests, types. Any agent can read that. The second is the *why*: why did this engineer reach for a store instead of a ref, why does that one always use `satisfies` instead of `as const`, why did the team decide eligibility checks must not mix concerns. That second layer lives in people's heads and in scattered PR comments, and it's what `codebase-rizz` exists to capture.

## Features

- **Generate code in a specific engineer's style.** "Write this the way Minh would." Personas are learned from real merged PRs and review comments, not hardcoded
- **Self-review against team patterns.** Checks a diff against `patterns.md` — the team's accumulated review rulebook — before you open a PR
- **Learn every day.** Daily and weekly crons scrape recent PRs and propose new patterns, persona updates, and long-form articles about how features work. Human merges all proposals
- **Track who's building what.** Lightweight ownership log that the skill uses as context for better persona matching and smarter suggestions
- **Per-repo isolation.** Knowledge never crosses between codebases. Each repo has its own `.codebase-rizz/` directory

## Install

```bash
# Clone into your Claude Code skills directory
mkdir -p ~/.claude/skills
git clone https://github.com/nguyenhoangminh1106/codebase-rizz ~/.claude/skills/codebase-rizz-src
ln -s ~/.claude/skills/codebase-rizz-src/skills/codebase-rizz ~/.claude/skills/codebase-rizz
```

Then in any repo, run:

```
/codebase-rizz bootstrap
```

It will verify `gh` CLI access, create `.codebase-rizz/` in the repo root, and ask for the GitHub usernames of the engineers you want to track.

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`) with `repo` and `read:org` scopes
- [Claude Code](https://claude.com/claude-code) with the `schedule` skill if you want crons to run on a timer

## Layout in your repo

After bootstrap, you'll have:

```
<repo-root>/.codebase-rizz/
├── rizz.config.json         # repo slug, tracked engineers, cron schedule
├── personas/
│   └── <github-username>.md
├── patterns.md              # team review rulebook
├── feature-ownership.md     # who's building what
├── articles/                # weekly technical writeups
└── proposed/                # cron output awaiting human merge (gitignored)
```

Commit `rizz.config.json`, `personas/`, `patterns.md`, `feature-ownership.md`, and `articles/`. Add `.codebase-rizz/proposed/` to `.gitignore` — it's ephemeral cron output until you merge it.

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
