---
name: codebase-rizz-code-like-auto
description: Given a coding task, pick the best-matching engineer persona for the current repo and generate code in their style. Reads all personas in <data_dir>/personas/, matches against the task, and delegates to code-like-person with the chosen persona. Use when the user wants code "in our team's style" but hasn't named a specific engineer, or says something like "how would we write this".
---

# generate / code-like-auto

Picks a persona for the current task, then delegates. This subskill does not generate code itself — it's the router between a task and a persona.

## Before doing anything

Resolve `<data_dir>` for the current repo via the registry lookup in `../_shared/paths.md`. If the lookup fails, tell the user to run `bootstrap` and stop.

## How to choose

1. Load every file under `<data_dir>/personas/`. Read the frontmatter (`strengths`, `triggers`, `anti_triggers`) of all of them — cheap, small.
2. Score each persona against the user's task description:
   - +2 for each `trigger` phrase that appears (substring or close synonym) in the task
   - +1 for each `strength` tag that matches the task domain
   - −3 for each `anti_trigger` that appears
3. Take the top 3 by score. Read their full persona files (principles, anti-patterns, example PRs, review quotes).
4. Make the final pick. If the top score is clearly ahead, use it. If the top 2 are within 1 point, read both files carefully and pick the one whose **anti-patterns** the current task would violate most — that's the engineer most qualified to steer the code away from trouble.
5. If no persona scores above 0, don't guess. Tell the user "none of the tracked engineers are a clear match — want me to generate without a persona, or do you want to name one?"

## Why this matching approach

Keyword matching alone produces silly results (a task about "state" routing to anyone who ever mentioned the word). Reading the full files of the top candidates gives Claude enough context to make a real judgment call. The tradeoff is latency — three file reads per dispatch — but personas are small, so it's cheap.

The anti-trigger tiebreaker is the important move: when two engineers could both handle a task, the one whose taste most strongly *objects* to the wrong approach is the more useful teacher.

## Handing off

Once a persona is chosen, delegate to `code-like-person/SKILL.md` with:
- The persona name (matches filename, matches GitHub username)
- The original user task, verbatim
- A one-line explanation of why this persona was picked, to share with the user

The child subskill owns the actual code generation. This one owns the choice.

## When to surface the choice to the user

Tell the user which persona was picked and why — one sentence — before handing off. If the user pushes back ("no, do it like Anthony"), re-dispatch to `code-like-person` with the named persona and skip the auto-match.

## Edge cases

- **No personas exist**: tell the user to run `bootstrap` first
- **Only one persona exists**: use it, no scoring needed
- **Task is a review, not a generation**: you're in the wrong subskill; redirect to `review`
- **User names an engineer explicitly**: skip the scoring, load that one persona file, delegate directly
