# The quality filter

This is the single source of truth for "is this observation worth learning?" Every skill that extracts knowledge from PRs or review comments — `learn-from-pr-comments`, `learn-from-persona-code`, and `backfill` — applies this filter before proposing anything.

Keeping the criteria in one file means the three skills stay consistent. If `from-pr-comments` lets style nitpicks through and `from-persona-code` filters them out, the knowledge base drifts into inconsistency.

## The one-sentence test

Before including any candidate observation in a proposal, answer this question:

> **If this observation were stripped of its PR context and shown to a mid-level engineer on a different team, would they learn something about code quality, design, or tradeoff reasoning that would transfer to their own work?**

- If yes → include
- If no → drop, even if it recurred many times or came from senior reviewers

This is a **teaching test**, not a correctness test. A comment can be 100% correct ("add a null check here") and still fail the filter if it doesn't teach anything transferable.

## Things that PASS the test

Include these. They're the whole point of the skill.

- **Prefer X over Y because Z** — where Z is a real constraint (performance, safety, reusability, a non-obvious subtlety in the codebase)
- **Abstraction boundary explanations** — "this lives in the repository layer because services shouldn't know about Prisma types"
- **Tradeoff reasoning** — "we chose the bundled PR over splitting because the refactor touches the whole area and splitting would just be churn"
- **Counterintuitive patterns** — "we tried the obvious approach and it broke because of X, so now we do Y"
- **Anti-patterns the team actively catches in review** with a stated reason ("never use forwardRef + useImperativeHandle for cross-tree coordination; it couples features that shouldn't know about each other")
- **Strong opinions expressed in review on someone else's design**, where the opinion would generalize beyond the one PR
- **Design constraints driven by external pressure** — "the legal team requires us to never log session tokens this way, so the auth middleware must do X"

The common thread: **a reader learns something they can apply in a different codebase**. The specific filenames change, the principle survives.

## Things that FAIL the test

Drop these even if they appear many times.

- **Naming conventions** — "use camelCase", "rename this variable", "this should be plural"
- **Formatting** — whitespace, import ordering, line breaks, trailing commas
- **Lint-fixable anything** — "use const instead of let", "missing semicolon", "unused variable"
- **Boilerplate additions** — "add a null check here", "add error handling"
- **Readability-only refactors** — "extract this into a helper function" when the only reason is "it's cleaner"
- **Typo fixes** — copy changes, spelling corrections, grammar
- **"Too long" observations** — "this file is too long", "this function is too long" without a deeper principle
- **Language tutorial stuff** — anything obvious to someone who has read a textbook on the language
- **Individual PR context** — "this specific call site needs to change" that doesn't generalize to a rule
- **Pure knowledge-of-the-codebase signals** — "this is already done in messageSlackChannel, remove the duplicate check" — useful in that PR, not a rule

The common thread: **the observation doesn't transfer**. Either it's taste about local polish, or it's tied to a specific file that doesn't exist in another codebase.

## Edge cases

**"It's a real pattern, but is it interesting?"**
Apply the transfer test strictly. "Use findUnique over findFirst when querying unique keys" is a real pattern **and** it transfers (it teaches intent-signaling in queries). "Use snake_case for Python filenames" is a real pattern but doesn't transfer (it's just a convention). Include the first, drop the second.

**"Naming that implies architecture"**
Sometimes naming is an anti-pattern signal — for example, "don't call it `recruiterPref` when it actually queries a generic user preference; names that inject interpretation hide the data model." That's about **how to think about variable names**, not about camelCase vs snake_case. Include it.

**"A senior reviewer said it, so it must be worth learning"**
No. The filter is author-agnostic. A senior reviewer pointing out a typo is still a typo. The transfer test doesn't care who said it.

**"It recurs 10 times"**
Recurrence matters for the signal threshold (how confident are we this is a team pattern?), but it doesn't matter for the quality filter. A formatting nitpick that happens 50 times is still a formatting nitpick. Drop it.

**"It's new, but I'm not sure"**
When in doubt, drop. A missed pattern can always be caught next week when another reviewer mentions the same thing. A polluted knowledge base is much harder to undo.

## What each skill does with this filter

- **`learn-from-pr-comments`** applies the filter to comments from trusted reviewers across daily-cron windows. Combined with its own signal threshold (2+ occurrences by default), this filter decides whether a theme becomes a pattern proposal
- **`learn-from-persona-code`** applies the filter to each engineer's own code and their review comments on others' PRs. Everything that passes can become a persona addition; everything that fails is dropped
- **`backfill`** applies the filter over much larger windows. Because the volume is higher, the signal threshold in backfill is stricter (5+ occurrences, 3+ reviewers) on top of this filter, not instead of it. Both must pass

## Tuning the filter

If the filter is producing too much noise in proposals, the first lever is **not** relaxing the threshold — it's making the filter stricter. If you find yourself writing things like "use semicolons" in `patterns.md`, something upstream let a fail-the-filter observation through. Check which skill produced it and tighten that skill's usage of this file.

Never edit the PASS/FAIL lists to accommodate a specific team's preferences. If your team cares about, say, naming conventions, that lives in a linter, not in codebase-rizz. This skill exists to capture the wisdom a linter can't.
