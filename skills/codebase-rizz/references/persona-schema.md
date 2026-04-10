# Persona file schema

Every file in `.codebase-rizz/personas/` describes one engineer and is keyed by their GitHub username. The filename is `<github-username>.md` — lowercase, exactly matching the GitHub handle, so `learn/from-persona-code` can find it automatically when scraping PRs.

## Structure

```markdown
---
name: minh2
display_name: Minh Pham
strengths: [frontend-state, zustand, refactors, drag-drop]
triggers:
  - state management
  - multi-component coordination
  - drag and drop
  - persistence / session storage
  - hoisting state out of refs
anti_triggers:
  - pure backend services
  - database schema design
---

# How Minh2 codes

## Mental model
One or two paragraphs about how this engineer thinks about problems. Not rules — frame. Why do they reach for stores instead of refs? What's the shape of the code they produce?

## Principles
- Short rules, each followed by the reason and a PR link.
- "Hoist state to Zustand stores, not useImperativeHandle refs, when the consumer lives outside the owning component's subtree. Reason: refs couple unrelated features; stores expose a flat API any importer can call. See PR #XXXX."

## Anti-patterns
What this engineer would reject in review. Same shape: rule + reason + PR link where possible.
- "Avoid forwardRef + useImperativeHandle for cross-tree coordination. Reason: it threads refs through roots that don't otherwise know each other. See thread on PR #XXXX."

## Example PRs
A handful of merged PRs that best represent this engineer's style. `learn/from-persona-code` appends here as it discovers more.
- #XXXX — consolidated chat widget store (zustand persist + merge schema)
- #XXXX — per-thread store registry

## Notes from review comments
Quotes pulled from their review comments on others' PRs. These are gold — they reveal the engineer's taste in their own words.
> "dont wanna do 2 consecutive setState thats 2 render" — PR #XXXX
```

## Field meanings

- **`name`**: GitHub username, matches filename
- **`display_name`**: Human name for the skill to use in prose
- **`strengths`**: Coarse tags used by `code-like-auto` as a fast filter before semantic matching
- **`triggers`**: Phrases that should route a task to this persona. Matched fuzzily against the user's request
- **`anti_triggers`**: Areas this engineer is *not* known for. If the task matches an anti-trigger, deprioritize this persona even if other signals match
- **`## Principles` / `## Anti-patterns`**: Rules with reasons. No rule should exist without a reason — rules without reasons rot
- **`## Example PRs`**: Grounding. When generating code, the skill can cite these
- **`## Notes from review comments`**: The richest source of persona voice

## How `code-like-auto` uses this file

1. Loads every file in `personas/` at runtime
2. Runs the user's task description against each persona's `triggers` and `anti_triggers`
3. Reads the top 1–3 candidates' full files to make the final choice
4. Hands off to `code-like-person/SKILL.md` with the chosen persona name

Never hardcode persona logic into `code-like-auto`. Adding an engineer should only require dropping a new `.md` file in `personas/`.

## How `learn/from-persona-code` writes to this file

The cron never edits this file directly. It writes a proposal to `proposed/personas/<username>-YYYY-MM-DD.md` following the same schema, containing only the *new* rules, examples, and review quotes it found. The human reviews the proposal and merges the additions manually — usually by appending to the right section.
