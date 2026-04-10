---
name: codebase-rizz
description: Learn any codebase's style, track who builds what, generate code in a specific engineer's voice, and get smarter every day from merged PRs. Use this skill whenever the user wants to write code matching a teammate's style, self-review code against team conventions, learn from past PR review comments, track feature ownership across a codebase, or bootstrap institutional knowledge from a GitHub repo. Works across multiple codebases with per-repo isolated knowledge.
---

# codebase-rizz

A skill that captures and applies the lived wisdom of a codebase — who codes how, what patterns the team cares about, and how features actually get built — then uses that knowledge to generate, review, and teach.

This is a **router skill**. It dispatches to one of several subskills based on what the user asks for. Each subskill lives in its own directory and has its own SKILL.md. Read this file first, then load only the subskill file you need.

## How to think about this skill

A codebase has two layers of knowledge. The first layer is the code itself — files, tests, types. Any agent can read that. The second layer is the *why*: why did Minh reach for a Zustand store instead of a ref, why does Anthony always use `satisfies` instead of `as const`, why did the team decide eligibility checks must not mix concerns. That second layer lives in people's heads and in scattered PR comments, and it's what this skill exists to capture.

The skill stores this knowledge **per repo**, in a `.codebase-rizz/` directory committed alongside the code. Knowledge from one repo never bleeds into another. Engineers are tracked by their GitHub username.

## Config layout (repo-local)

Every repo the skill works with has this structure:

```
<repo-root>/.codebase-rizz/
├── rizz.config.json         # repo slug, tracked GitHub usernames, cron schedule
├── personas/                # one file per engineer, keyed by GitHub username
│   └── <github-username>.md
├── patterns.md              # team-wide review checklist
├── feature-ownership.md     # who is currently building what
├── articles/                # weekly learning articles (from learn/from-codebase)
└── proposed/                # cron output awaiting human merge
    ├── patterns/
    └── personas/
```

A global per-user registry at `~/.claude/skills/codebase-rizz/registry.json` tracks the list of repos the skill knows about. It contains nothing else — no knowledge, no code.

`patterns.md`, `personas/`, `feature-ownership.md`, and `articles/` are meant to be committed so the team shares them. `proposed/` should be gitignored — it's ephemeral cron output until a human merges it, and committing it would cause merge churn between machines running the crons.

## Subskill router

When the user asks for something, load the matching subskill file:

| User intent | Load |
|---|---|
| First time setup in a repo, add an engineer, check gh works | `bootstrap/SKILL.md` |
| "Write this in Minh's style" / "how would Anthony do this" | `generate/code-like-auto/SKILL.md` (delegates to `code-like-person/` once a persona is chosen) |
| "Review my diff" / "check this against our patterns" | `review/SKILL.md` |
| "Learn from yesterday's PRs" (cron or manual) | `learn/from-pr-comments/SKILL.md` |
| "Update personas from their recent code" (cron) | `learn/from-persona-code/SKILL.md` |
| "Write an article about a feature" (weekly cron) | `learn/from-codebase/SKILL.md` |
| "Check if any patterns are stale" (weekly cron) | `learn/patterns-drift/SKILL.md` |
| "Track that Minh is building the CRM quick actions" | `track/assign/SKILL.md` |
| Daily reconcile of ownership vs actual PR authors | `track/reconcile/SKILL.md` |

If the user's request is ambiguous, ask which subskill they want before loading. Loading the wrong subskill produces an answer shaped like the wrong tool, which is worse than a brief clarifying question.

## Shared preconditions

Before any subskill that touches GitHub runs, the gh preflight check must pass. See `references/gh-preflight.md` for the exact sequence. The preflight is cached per session in `/tmp/codebase-rizz-gh-check` so it only runs once.

Before any subskill that reads or writes repo-local config, verify `.codebase-rizz/` exists. If it doesn't, tell the user to run `bootstrap` first instead of silently creating files.

## Design principles

**Every learned thing is a proposal.** Crons never write directly to `patterns.md` or `personas/*.md`. They write to `proposed/` and the human merges. This is non-negotiable — without it, the skill drifts and poisons its own training data.

**Per-repo isolation.** A persona file under `repo-A/.codebase-rizz/personas/minh2.md` has zero influence on `repo-B`. If the same engineer works on both, they get two persona files, one per repo.

**Personas are data, not hardcoded.** The persona dispatcher reads every file under `personas/` at runtime, matches against the user's task, and picks one. Adding a new engineer is a new file — no code changes.

**Explain the why.** When the skill writes a persona rule or a pattern, it includes the reason (usually a linked PR comment). Rules without reasons decay. Rules with reasons stay useful.

## References

- `references/gh-preflight.md` — the 4-step GitHub CLI check
- `references/persona-schema.md` — the format every persona file must follow
- `references/config-schema.md` — the format of `rizz.config.json`
