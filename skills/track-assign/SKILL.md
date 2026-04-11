---
name: track-assign
description: Record that a specific engineer is building a specific feature. Updates <data_dir>/feature-ownership.md with an entry including engineer GitHub username, feature description, and start date. Use when the user says "Minh is working on X", "I'm starting the Y refactor", or similar ownership declarations.
---

# track / assign

Records an ownership claim. Tiny subskill — one file, one append.

## Before doing anything

Run the preflight from `../_shared/paths.md` to resolve `<data_dir>` for the current repo. Stop with the guidance in that file if any preflight step fails.

## Inputs

- **engineer**: GitHub username, must match a file in `<data_dir>/personas/` (warn but proceed if it doesn't — the user may be tracking someone who isn't a persona yet)
- **feature**: short description, 1–2 sentences
- **branch** (optional): the branch name where the work is happening, if known
- **linear_ticket** (optional): ticket ID if the team uses Linear/Jira

If the user's request is ambiguous, ask for the engineer and feature explicitly. Don't guess — a wrong entry poisons `track/reconcile` later.

## The file

`<data_dir>/feature-ownership.md`. Create it if it doesn't exist. Structure:

```markdown
# Feature ownership

Who is currently building what. Updated by `track/assign` and reconciled daily by `track/reconcile`.

## Active

### minh2 — CRM quick actions
- **Started**: 2026-04-10
- **Branch**: crm-quick-actions
- **Ticket**: ENG-5987
- **Status**: active

### anthnykr — auth middleware rewrite
- **Started**: 2026-04-08
- **Branch**: auth-rewrite-v2
- **Status**: active

## Completed (last 30 days)

### eliang — design system button v2
- **Started**: 2026-03-15
- **Completed**: 2026-04-02
- **Ticket**: DS-204
```

## What to append

New assignments go under `## Active` with today's date (ISO format, derived from the system date — convert any relative dates the user gives). Keep the list sorted by start date, most recent first.

If the same engineer already has an active entry and the user is giving a new feature, ask whether the new one replaces the old or adds to it. Multi-tasking is fine — just confirm intent.

## What this subskill does not do

- **Does not mark anything complete.** That's `track/reconcile`'s job (when it sees the branch merged) or a manual edit
- **Does not fetch data from GitHub.** Assignments are user-declared. If the user wants automatic ownership inference, they should run `track/reconcile`
- **Does not update persona files.** Ownership information is used as *context* by `learn/from-persona-code` but isn't part of the persona itself

## Reporting back

One sentence: "Logged: <engineer> is building <feature> (started <date>)." If the engineer doesn't have a persona file, add: "Heads up — no persona file for <engineer> yet. Run bootstrap to add them if you want code-like-<name> to work."
