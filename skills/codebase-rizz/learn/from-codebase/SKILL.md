---
name: codebase-rizz-learn-from-codebase
description: Weekly cron that picks one un-documented feature from the codebase and writes a narrative technical article explaining how it works and why. Saves to <data_dir>/articles/. Use when the user wants to deeply understand a feature, or let it run on schedule to build up a library of codebase knowledge.
---

# learn / from-codebase

Weekly cron. Every Sunday morning, pick one feature that hasn't been written about yet and produce a long-form technical blog post about it. This is Hari's daily-article idea, slowed to weekly because interesting features deplete fast at daily cadence.

## Before doing anything

Resolve `<data_dir>` for the current repo via the registry lookup in `../../references/paths.md`. As a multi-repo cron, iterate the registry and pick at most one feature per repo per run.

## Schedule

Default: Sunday 9:00am. Configured via `crons.from_codebase` and loaded as a launchd user agent by bootstrap. See `../../references/crons.md`.

## Pick a feature

1. List everything already covered in `<data_dir>/articles/`. Read the filenames and the first heading of each file.
2. Identify candidate features in the repo that *aren't* yet covered. Good candidates:
   - Recently merged non-trivial PRs (large diffs, multi-file, introduce new abstractions)
   - Subsystems with dedicated directories (`components_new/consolidated-messaging/`, `lib/services/*`)
   - Crons, background jobs, webhook handlers
   - State management and data flow setups
3. Prioritize features that connect multiple parts of the codebase — the more threads an article can pull on, the more valuable the writeup.
4. Pick **one**. Don't try to cover multiple features in one run.

If there are no clear candidates (the repo is small or well-documented already), skip this run and note it in a log line.

## Research the feature

Read the relevant files end-to-end. Not scanning — actually read. A good article needs:
- The entry point (where user interaction or external triggers start the flow)
- The data shape (types, schema, stores)
- The orchestration (which functions call which, in what order)
- The non-obvious decisions (why a store instead of a ref, why this middleware config, why this specific threshold)

If the feature has associated PR discussions (look up the PRs that introduced it with `gh`), read the review threads. The original debate is often the best source of *why*.

## Article structure

Follow this shape loosely — adapt to the feature:

```markdown
# <Feature name>: <subtitle that hints at the why>

## The problem this solves
Frame the problem in user or product terms, not implementation terms.

## The state ladder / design space
Name the alternatives the team could have picked, and briefly say why they weren't chosen.

## <Section per major component>
Walk through the actual implementation. Reference files and line numbers liberally.

## Why this shape (and not the obvious alternatives)
The payoff. This is the section the reader came for.

## When this pattern generalizes
Brief note on what other features in the codebase could use the same approach.
```

Include a Mermaid diagram if the flow is non-trivial. Use file paths as anchors (`components/Foo.tsx:42`) so readers can jump around.

## Tone

Narrative, not reference. "There was a moment when the team realized X" beats "the following is a list of functions." Write it like a dev blog post someone would actually read cover to cover, not like an internal wiki page.

## Output

Save to `<data_dir>/articles/YYYY-MM-DD-<feature-slug>.md`. The slug should be short and human-readable (`frontend-state-with-zustand`, not `components_new_consolidated_messaging_widget`).

## What to report (manual invocation)

- The feature picked and why it was picked over others
- A 2-sentence preview of the angle
- The path to the saved article
- How long the article is (word count)

## Not this subskill's job

- Updating persona files (that's `from-persona-code`)
- Deriving team patterns (that's `from-pr-comments`)
- Suggesting refactors (that's `review`)

This one is purely about producing readable explanations. A good article outlives any specific implementation — it captures the reasoning even after the code changes.
