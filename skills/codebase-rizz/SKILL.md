---
name: codebase-rizz
description: Learn any codebase's style, track who builds what, generate code in a specific engineer's voice, and get smarter every day from merged PRs. Use this skill whenever the user wants to write code matching a teammate's style, self-review code against team conventions, learn from past PR review comments, track feature ownership across a codebase, or bootstrap institutional knowledge from a GitHub repo. Works across multiple codebases with per-repo isolated knowledge.
---

# codebase-rizz

A skill that captures and applies the lived wisdom of a codebase — who codes how, what patterns the team cares about, and how features actually get built — then uses that knowledge to generate, review, and teach.

This is a **router skill**. It dispatches to one of several subskills based on what the user asks for. Each subskill lives in its own directory and has its own SKILL.md. Read this file first, then load only the subskill file you need.

## How to think about this skill

A codebase has two layers of knowledge. The first layer is the code itself — files, tests, types. Any agent can read that. The second layer is the *why*: why did Minh reach for a Zustand store instead of a ref, why does Anthony always use `satisfies` instead of `as const`, why did the team decide eligibility checks must not mix concerns. That second layer lives in people's heads and in scattered PR comments, and it's what this skill exists to capture.

The skill stores this knowledge **per repo**. Each repo has a data directory with the same layout, but *where* that directory lives is a choice the user makes during `bootstrap`:

- **Global** (`~/.codebase-rizz/repos/<slug>/`) — private to the user, no footprint in the repo. Good for solo use or trying the skill without committing to team adoption
- **Repo-local** (`<repo-root>/.codebase-rizz/`) — committed with the code, shared with the team via git

Both modes use the identical layout inside the data directory. Every subskill resolves the current repo's `data_dir` via a lookup in `~/.codebase-rizz/registry.json` — see `references/paths.md` for the exact mechanism. **Never hardcode `.codebase-rizz/` anywhere**; always resolve through the registry.

## Data directory layout (regardless of storage mode)

```
<data_dir>/
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

In **repo-local** mode, `proposed/` should be added to the repo's `.gitignore` — it's ephemeral cron output and committing it would cause merge churn between machines running the crons. Everything else in the data directory is meant to be committed so the team shares it.

In **global** mode, nothing ever touches the repo's working tree.

## The registry

`~/.codebase-rizz/registry.json` is the single source of truth for which repos the skill knows about and where each one's data lives. Every subskill reads it first to resolve the current repo's `data_dir`. See `references/paths.md` for the schema and the lookup pseudocode.

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
| "Move this repo's rizz data from global to repo-local (or back)" | `migrate/SKILL.md` |

If the user's request is ambiguous, ask which subskill they want before loading. Loading the wrong subskill produces an answer shaped like the wrong tool, which is worse than a brief clarifying question.

## Shared preconditions

Every subskill except `bootstrap` and `migrate` does these checks in order before doing anything else:

1. **Resolve the repo's `data_dir`** via `references/paths.md`. If the current repo isn't in the registry, tell the user to run `bootstrap` first — don't silently create files
2. **Run the gh preflight** if the subskill touches GitHub. See `references/gh-preflight.md`. Cached per session so it only runs once

If either check fails, stop and print the specific remediation. No silent fallbacks.

## Design principles

**Every learned thing is a proposal.** Crons never write directly to `patterns.md` or `personas/*.md`. They write to `proposed/` and the human merges. This is non-negotiable — without it, the skill drifts and poisons its own training data.

**Per-repo isolation.** A persona file under `repo-A/.codebase-rizz/personas/minh2.md` has zero influence on `repo-B`. If the same engineer works on both, they get two persona files, one per repo.

**Personas are data, not hardcoded.** The persona dispatcher reads every file under `personas/` at runtime, matches against the user's task, and picks one. Adding a new engineer is a new file — no code changes.

**Explain the why.** When the skill writes a persona rule or a pattern, it includes the reason (usually a linked PR comment). Rules without reasons decay. Rules with reasons stay useful.

## References

- `references/paths.md` — how to resolve `data_dir` from the registry; slug derivation; storage modes
- `references/gh-preflight.md` — the 4-step GitHub CLI check
- `references/persona-schema.md` — the format every persona file must follow
- `references/config-schema.md` — the format of `rizz.config.json`
