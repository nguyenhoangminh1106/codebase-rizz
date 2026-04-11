---
name: code-like-person
description: Generate code in a specific named engineer's style, using their persona file from <data_dir>/personas/. Called by code-like-auto once a persona is chosen, or directly when the user names an engineer ("write this like Minh would"). Requires a persona name matching an existing file.
---

# code-like-person

Generates code in one named engineer's voice. This is the leaf subskill — it does the actual writing.

## Before doing anything

Run the preflight from `../_shared/paths.md` to resolve `<data_dir>` for the current repo. Stop with the guidance in that file if any preflight step fails.

## Inputs

- **persona_name**: required. Must match a filename in `<data_dir>/personas/` (without the `.md`)
- **task**: required. The user's coding request, verbatim
- **why_picked**: optional. One-line explanation from `code-like-auto`, to repeat back to the user

## Before writing any code

Read the persona file in full. All of it — frontmatter, mental model, principles, anti-patterns, example PRs, review quotes. This is the ground truth for this invocation. Do not generate from persona tags alone.

If the persona file doesn't exist, stop and tell the user which personas are available (list filenames in `personas/`). Don't guess or fall back to a different engineer.

## How to write the code

Use the persona file as a constraint in four ways:

1. **Principles as hard constraints.** Every principle in the file is a rule the code must obey. If a principle says "hoist state to stores not refs," the generated code must not use `useImperativeHandle`. If you find yourself wanting to break a principle because it feels wrong for this task, that's a signal the persona might not fit — surface the conflict to the user instead of overriding silently.

2. **Anti-patterns as guardrails.** Before finalizing, re-read the Anti-patterns section and check your draft against it. If the draft contains something the persona would reject in review, rewrite it.

3. **Mental model as framing.** Use the mental model paragraph to shape the *structure* of the solution — which abstractions to reach for, which files to touch, what shape the final diff looks like. This is where persona voice lives. Two engineers can both follow all the rules and still produce very different code; the mental model is the tiebreaker.

4. **Review quotes as reminders.** If a direct quote is relevant ("dont wanna do 2 consecutive setState thats 2 render"), the generated code should implicitly honor it. You don't need to cite the quote in comments — just respect it.

## What to include in the response

When handing the code back to the user:

- One sentence stating which persona was used and why (repeat `why_picked` if provided, otherwise generate one)
- The code itself
- A short "why this shape" note — 2–3 bullets explaining which principles from the persona file drove the non-obvious choices. Cite the persona file and PR numbers where relevant
- If you had to break a principle to complete the task, call it out explicitly: "Minh's persona says avoid X, but this task requires it because Y — flagging for you to decide"

The "why this shape" note is the most important part. Without it, the user can't tell whether the code is actually persona-driven or just generic code with an attribution. With it, they learn the persona alongside getting the code.

## What not to do

- Don't add comments like `// Minh would write it this way`. The persona is the reason, not the documentation
- Don't copy example code from `## Example PRs` verbatim. Those are references for *you*, not templates
- Don't blend two personas. If the user asks for Minh's style, the output is Minh's style, full stop
- Don't update the persona file from this subskill. Persona updates come only from `learn/from-persona-code`, and only as proposals
