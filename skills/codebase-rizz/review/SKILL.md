---
name: codebase-rizz-review
description: Self-review a diff or branch against the team's patterns.md checklist in .codebase-rizz/. Flags violations, cites the specific pattern number and reason, and suggests fixes. Use before the user opens a PR, or whenever they say "review this" / "check my diff" / "is this following our conventions".
---

# review

Checks a diff against the team's accumulated review patterns. This is the "self-review before PR" subskill.

## Inputs

The diff to review. Figure out which, in this priority order:

1. If the user named files or a PR number, use those
2. If there are staged changes (`git diff --cached`), use those
3. If there are unstaged changes (`git diff`), use those
4. If the branch differs from `default_branch` in `rizz.config.json`, use `git diff <default_branch>...HEAD`
5. If none of the above, ask the user what to review

## The checklist

Read `.codebase-rizz/patterns.md`. This is the team's review rulebook, written and appended to by humans and by `learn/from-pr-comments`. Each pattern should have a number, a short rule, a *why*, and usually a PR link. Treat each one as a check to run against the diff.

If `patterns.md` doesn't exist, tell the user to run `bootstrap` or add patterns manually. Don't review against a generic checklist — this skill is specifically about *this team's* conventions.

## How to run the checks

For each pattern, ask: "does anything in this diff violate this rule?" Be specific about what the rule means — read the *why* and the linked PR if provided, because the rule's wording often undersells its scope.

For each violation, produce:
- Pattern number and short rule
- The specific file + line range in the diff
- What's wrong
- The fix (code snippet if small, description if structural)
- A link to the pattern's source PR if present

Don't flag things that aren't in `patterns.md`. Generic "this could be cleaner" feedback dilutes the signal. If you notice something outside the checklist that genuinely matters, put it in a separate "Observations (not in patterns)" section at the end so the user can decide whether to add it as a new pattern.

## Persona-aware review (optional)

If the diff's author is known (from git blame or the current branch's commits), and there's a persona file for them, additionally check the diff against *their* persona's principles and anti-patterns. This catches things like "Minh usually would have used a store here" that aren't team-wide patterns but are personal taste the team respects.

Flag persona-level findings separately from pattern violations. Persona findings are suggestions; pattern violations are blockers.

## Output format

```
## Pattern violations (N)

### Pattern #7: All Prisma calls belong in repositories, not services
**File**: lib/services/user.service.ts:42–51
**Issue**: Direct prisma.user.findFirst() call inside UserService.getByEmail()
**Fix**: Move to UserRepository.findByEmail() and call it from the service
**Source**: [patterns.md#7], PR #9897

### Pattern #13: Remove unnecessary type assertions
...

## Persona observations (N)

### Minh2 — anti-pattern: forwardRef + useImperativeHandle for cross-tree coordination
**File**: components/ChatWidget.tsx:18
**Suggestion**: Consider lifting this into a Zustand store so CheckInPage can dispatch into it directly
**Source**: minh2.md, PR #XXXX

## Observations (not in patterns)

- Nothing to flag, or things the user might want to promote to patterns
```

If there are zero violations and zero observations, say so plainly: "Clean against all N patterns." Don't pad.

## What this subskill does not do

- Does not run tests, lint, or type-check. Those are other tools; this one is about team wisdom
- Does not rewrite the diff — only suggests
- Does not update `patterns.md`. New patterns come from `learn/from-pr-comments` as proposals
