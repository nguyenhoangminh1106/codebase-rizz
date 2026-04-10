---
name: codebase-rizz-patterns-drift
description: Weekly cron that checks whether any patterns in patterns.md are being violated in recently merged code, suggesting the pattern is either stale or being ignored. Writes proposals for removal or re-emphasis to <data_dir>/proposed/patterns/. Never removes patterns directly.
---

# learn / patterns-drift

Weekly cron. Keeps `patterns.md` honest by checking whether the rules are actually being followed. If a rule is routinely broken in merged PRs and nobody's calling it out in review, the rule is either wrong, outdated, or forgotten — all three deserve attention.

## Before doing anything

Resolve `<data_dir>` for the current repo via the registry lookup in `../_shared/paths.md`. Iterate the registry when running as a cron; skip repos whose `patterns.md` doesn't exist yet.

## Schedule

Default: Sunday 9:30am (after `from-codebase` finishes). Configured via `crons.patterns_drift` and loaded as a launchd user agent by bootstrap. See `../_shared/crons.md`.

## How drift is measured

For each pattern in `<data_dir>/patterns.md`:

1. **Translate the rule into a check.** Most patterns describe a thing to avoid (direct Prisma in services, nested ternaries, ButtonLegacy). Turn each into a grep-able or AST-checkable signal.
2. **Run the check against recently merged code** — the last 4 weeks by default. Use `git log --since=...` to get the range, then check each merged commit's added lines.
3. **Count violations.** If a rule that says "never X" has 5+ fresh occurrences of X in merged code, that's drift.
4. **Cross-reference with review comments.** For each violation found, check whether anyone commented on it during review. If reviewers caught it and the author fixed it before merge, that's not drift — the rule is working. If it merged with no comment, that's real drift.

## Three verdicts per pattern

For each pattern, produce one of:

- **Still holding** — no violations, or all violations were caught in review. No action needed, don't report
- **Being ignored** — violations are merging without comment. Propose either re-emphasis (pin at the top of `patterns.md`, re-share with the team) or removal if the team has clearly moved on
- **Possibly stale** — the rule is technically violated but the violations look *intentional* (e.g., a new framework convention replaced the old rule). Propose reviewing and rewriting the rule

## Write the proposal

```markdown
# Patterns drift report — week of YYYY-MM-DD

## Still holding: 23 / 27 patterns clean

## Being ignored (3)

### Pattern #14: Reuse existing constants from shared modules
**Drift**: 6 new hardcoded ID lists in merged PRs, 0 review comments flagging them
**Most recent**: PR #XXXX, components/FooPanel.tsx:12
**Suggestion**: Re-share in team channel, or add a linter rule

### Pattern #25: Always use design system components
...

## Possibly stale (1)

### Pattern #8: Use satisfies over as const for Prisma select/where objects
**Observation**: Most new Prisma queries use typed helper functions now, sidestepping the choice entirely. The rule may be obsolete for new code and only apply to legacy refactors.
**Suggestion**: Rewrite the rule to clarify scope, or remove
```

Save to `<data_dir>/proposed/patterns/drift-YYYY-MM-DD.md`.

## Why this matters

`patterns.md` grows monotonically by default — `learn/from-pr-comments` only adds. Without a drift check, the file fills with stale rules that nobody follows, which slowly turns the whole review subskill into noise. Drift detection is the pruning mechanism.

## What to report (manual invocation)

- Total patterns checked
- Counts: still holding, being ignored, possibly stale
- Path to the proposal file

## Constraints

- **Never delete or rewrite patterns directly.** Every change is a proposal
- **Don't flag a pattern as stale based on 1–2 violations.** Noise. Use a threshold of at least 4 distinct violations over the window
- **Don't run if `patterns.md` has fewer than 10 patterns.** The drift signal isn't meaningful on a small ruleset, and the proposal will just be noise
