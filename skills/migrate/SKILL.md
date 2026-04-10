---
name: migrate
description: Move a repo's codebase-rizz data between global storage (~/.codebase-rizz/repos/<slug>/) and repo-local storage (<repo>/.codebase-rizz/). Copies all files, updates the registry, and handles gitignore. Use when a solo user wants to start sharing with their team, or when a team wants to pull shared knowledge back to private storage.
---

# migrate

Moves a repo's data directory between storage modes. Always confirm with the user before touching files — migration is a one-way operation per run.

## Before doing anything

Resolve the current repo's registry entry via the lookup in `../_shared/paths.md`. If the lookup fails (repo never bootstrapped), tell the user to run `bootstrap` first. There's nothing to migrate if there's no data.

## Determine direction

Ask the user explicitly — don't infer:

> Your repo currently uses **<current_storage>** storage at `<current_data_dir>`.
>
> Where do you want to move it to?
>
> **1) Global** (`~/.codebase-rizz/repos/<slug>/`) — private to you
> **2) Repo-local** (`<repo-root>/.codebase-rizz/`) — committed, team-shared
>
> Pick 1 or 2:

If the user picks the mode it's already in, say "already there, nothing to do" and exit.

## The migration, step by step

Do all steps in one atomic sequence. If any step fails, roll back what you can and report clearly.

1. **Compute the target path.**
   - Global → repo-local: `target = <repo-root>/.codebase-rizz`
   - Repo-local → global: derive slug from remote URL per `../_shared/paths.md`, `target = ~/.codebase-rizz/repos/<slug>`

2. **Check the target doesn't already exist.** If it does, stop and ask the user what to do — merging two data dirs is beyond this subskill's scope, and we don't want to clobber.

3. **Copy the files.** Use `cp -R` (not move) so the source remains intact until the registry update succeeds. Preserve directory structure: `rizz.config.json`, `personas/`, `patterns.md`, `feature-ownership.md`, `articles/`, `proposed/`.

4. **Verify the copy.** Compare file counts and a checksum of `rizz.config.json` between source and target. If they don't match, delete the partial target and bail — do not update the registry.

5. **Update `~/.codebase-rizz/registry.json`.** Find the entry for this repo, update `storage` and `data_dir` to the new values. Write back atomically (write to `registry.json.tmp`, then rename).

6. **Handle gitignore.**
   - Migrating **to repo-local**: append `.codebase-rizz/proposed/` to the repo's `.gitignore` (create if missing, skip if already present)
   - Migrating **to global**: no gitignore changes needed (nothing lives in the repo anymore)

7. **Delete the source.** Only after the registry update has succeeded and been verified. Use the old path from the registry entry you just updated.
   - If migrating to global, the source is inside the repo — `rm -rf <repo-root>/.codebase-rizz`
   - If migrating to repo-local, the source is in `~/.codebase-rizz/repos/<old-slug>`

8. **Report to the user.**
   - The new `data_dir` path
   - How many files moved
   - The gitignore changes made, if any
   - A reminder: if the user migrated *to* repo-local, they still need to `git add` and commit the new directory. If they migrated *from* repo-local, they should `git rm -r .codebase-rizz/` in a follow-up commit so the dir doesn't linger in history.

## Why copy-then-delete instead of move

Moving across filesystems (home dir → repo) can fail partway and leave both sides broken. Copying first lets us verify integrity before making anything destructive. The registry is the single source of truth for *where* the live data is, so we only ever have one authoritative location after step 5.

## What migrate does NOT do

- **Does not merge two existing data dirs.** If both source and target already have content, stop and ask the user to resolve manually
- **Does not rewrite file content.** Personas, patterns, articles — all move verbatim. The schemas are identical between storage modes
- **Does not update the launchd agents.** The cron plists reference absolute paths. After migration, the user needs to unload the old agents and re-run bootstrap (or manually re-run the cron install step) so the new paths take effect. Migrate prints the exact `launchctl unload`/`load` commands at the end
- **Does not modify git history.** The user commits or un-commits the repo-local files themselves

## Failure modes

- **Target path already populated**: stop before copying, ask user
- **Copy partially succeeds**: delete the partial target, don't touch the registry, report
- **Registry write fails**: the copy already succeeded, so warn the user that both locations now have the data and ask them to re-run migrate or fix `registry.json` by hand
- **Source delete fails**: the migration technically succeeded (registry points to the new location), so warn the user the old dir is still on disk and needs manual cleanup
