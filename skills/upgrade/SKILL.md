---
name: upgrade
description: Migrate an already-bootstrapped repo (or every repo in the registry) from an older version of codebase-rizz to the current one. Reads CHANGELOG.md to find out what changed between versions, walks the user through each new feature, updates rizz.config.json, refreshes the permissions allowlist in settings.json, regenerates all launchd plists from the current template, and writes the new version number. Use whenever the user reinstalls or updates codebase-rizz and wants everything in sync without re-bootstrapping.
---

# upgrade

The version-aware twin of `bootstrap`. Bootstrap is for first-time setup in a new repo; upgrade is for taking an existing setup and walking it forward through whatever has changed since it was bootstrapped.

## Before doing anything

1. **Figure out the scope of this invocation.** If the user is inside a git repo and that repo is in the registry, treat this as a single-repo upgrade *by default*. If the user runs upgrade from outside any repo, or explicitly asks to upgrade all repos, iterate the registry.

2. **Resolve the skill's current version.** Read `../CHANGELOG.md` (one level up from this subskill dir — `install.sh` copies the changelog to the skill root so it's always at the same place regardless of where upgrade is invoked from). The highest `## v<N>` header is the current version. Parse it into an integer.

3. **Determine which repo(s) to migrate.** For single-repo: resolve the current repo via `../_shared/paths.md` registry lookup. For all-repos: iterate every entry in `~/.codebase-rizz/registry.json`.

## Reading the changelog

The changelog format is structured and machine-readable. For each version entry, extract:
- `scope` — `this_repo` or `all_repos`
- `title` — short summary to show the user
- `new_config_keys` — list of dotted paths with defaults
- `new_subskills` — list of newly-added subskill paths
- `new_notification_events` — list of new event keys for the `notifications.events` block
- `migration` — plain-English description of what upgrade should do
- `details` — multi-paragraph explanation to show the user as context

Parsing rule: the format uses `- **field**:` lines for scalar/list fields, and `- **details**: |` followed by indented lines for the multi-line prose. Don't try to parse it as strict YAML — read line by line and use the prose directives, not arbitrary YAML semantics.

## Core decision: per-repo vs fan-out

Upgrade's behavior depends on the `scope` of the changelog entries the user is behind on.

### Case A: the user is behind on one or more versions, all scope=`this_repo`

1. Tell the user what's new (print `title` and `details` for each version they're behind on)
2. Walk through each version in order (oldest to newest), asking per new config key or feature whether they want to opt in
3. Update the current repo's `rizz.config.json` — set the new `version`, add the new keys with defaults the user accepted, generate any new launchd plists, print the `launchctl load` commands
4. Done with the current repo. Do NOT touch other repos in the registry

### Case B: the user is behind on one or more versions, any have scope=`all_repos`

1. First, handle the current repo exactly as in Case A (with everything — both this_repo and all_repos migrations)
2. After the current repo is done, ask the user:

   > I noticed version <N> is marked as a skill-wide change. You have M other repos in your registry. Do you want me to upgrade them too? (y/n)
   >
   > I'll walk through each one and ask you the same questions, so nothing is applied silently.

3. If yes, iterate the remaining repos. For each, print "Upgrading <slug>..." and walk through the same prompts
4. If no, tell the user they can run `/codebase-rizz:upgrade` from inside any other repo later to migrate it individually

Fan-out is **opt-in per invocation** — upgrade never silently edits a repo the user didn't ask about.

## Handling each type of change

### New config key

For each key in `new_config_keys`:

1. Check if the current `rizz.config.json` already has it (could happen if the user hand-edited their config)
2. If it already exists: skip, log "already set to <current value>"
3. If missing: ask the user. Phrase the prompt based on the migration description in the changelog, not generically. For opt-in features like `auto_review.mode`, use the same three-option prompt bootstrap uses
4. Apply the answer to the config (in memory — write at the end)

### New subskill

Nothing to do in the config — the subskill is just added to the skill code. But show it to the user in the "what's new" list so they know to try it.

### New notification event

If the user has `notifications.enabled: true`, ask: "There's a new event (`<event_key>` — <description>). Want notifications for this? (y/n, default yes)"

If the user has notifications off entirely, skip this — don't nag them about events they won't receive.

### New launchd cron agent

If a new cron key is being added and the user opts in (or the default is to enable it), generate the plist using the template in `../_shared/crons.md`, write it to `~/Library/LaunchAgents/com.codebase-rizz.<slug>.<cron-key>.plist`, and add the `launchctl load` command to the "run these after" list.

Don't run `launchctl load` automatically. Print the commands at the end of the run and let the user paste.

## Refresh permissions allowlist

After walking through all version prompts but **before** writing the updated config, re-merge the permissions allowlist from `../_shared/permissions.md` into `~/.claude/settings.json`. This ensures any new permissions added in newer plugin versions take effect without a full re-bootstrap.

1. Read the current allowlist from `../_shared/permissions.md`
2. Read the user's existing `~/.claude/settings.json`
3. Diff the two `permissions.allow` arrays. If the plugin's list has rules not present in the user's settings, show them:

   > The plugin now requires these additional permissions that aren't in your settings.json:
   >
   > ```
   > Bash(git blame:*)
   > ```
   >
   > Merge into `~/.claude/settings.json`? (y/n)

4. If yes, merge (same atomic write as bootstrap — temp + rename). If no, warn that some crons may silently fail
5. If the allowlist is already up to date, print "Permissions allowlist is current — no changes needed." and move on

## Regenerate launchd plists

After refreshing permissions, regenerate **all existing plists** for this repo using the current template from `../_shared/crons.md`. This picks up template-level fixes (like the `ulimit` fix) without requiring the user to manually edit plist files.

1. For each cron key in the repo's `rizz.config.json.crons`, check if a plist already exists at `~/Library/LaunchAgents/com.codebase-rizz.<slug>.<cron-key>.plist`
2. If it exists, regenerate it from the current template (overwrite). This picks up any template changes (ulimit, PATH updates, flag changes)
3. If it doesn't exist (new cron from a version migration), generate it fresh — this is the existing behavior for new crons
4. After regenerating, print all `launchctl unload` + `launchctl load` commands for the user to run:

   > Your existing cron plists have been regenerated with the latest template. Run these to reload them:
   >
   > ```bash
   > launchctl unload ~/Library/LaunchAgents/com.codebase-rizz.<slug>.from-pr-comments.plist
   > launchctl load ~/Library/LaunchAgents/com.codebase-rizz.<slug>.from-pr-comments.plist
   > # ... (one pair per plist)
   > ```

5. Don't run `launchctl` automatically — print the commands and let the user paste, same as bootstrap

Skip plist regeneration entirely if the user is not on macOS.

## Writing the updated config

After all prompts are answered for a repo:

1. Read the current config
2. Merge in the new keys (don't overwrite existing ones that weren't part of this migration)
3. Set `version` to the new highest version number
4. Atomic write: temp file + rename

If anything fails mid-migration, do not write the version field. The user can re-run upgrade — it will notice the repo is still on the old version and retry.

## Config without a version field

Any `rizz.config.json` that has no `version` key is treated as **v1**. This lets us migrate pre-versioning configs (users who bootstrapped before we added the `version` field) into the new system without breaking anything.

## Reporting back

At the end of the run, per repo:
- Version before → version after
- Which new config keys were added (and the user's choices)
- Which new cron plists were generated (with the exact `launchctl load` commands)
- Which new notification events were opted into
- Any errors or skipped items

At the very end of a fan-out run, print a table of all repos and what happened to each one, so the user can see the big picture.

## What upgrade does NOT do

- **Does not remove config keys** — if a future version deprecates a key, leave it in the user's config unless the migration explicitly says to remove it. Silent removals break user trust
- **Does not delete old launchd plists** — if a cron is renamed or removed, the migration must explicitly say so, and the subskill prints `launchctl unload` + `rm` commands for the user to run manually. (Existing plists ARE regenerated from the current template to pick up fixes, but never deleted)
- **Does not run any cron** — neither the old ones nor the new ones. First fire is at the scheduled time
- **Does not touch knowledge files** — never edits `patterns.md`, persona files, or articles. Only config, permissions, and plists
- **Does not auto-answer opt-in prompts**. Every choice is a deliberate user action

## Edge cases

- **User is on the current version already**: print "Already on v<N>, nothing to migrate" and exit
- **User is more than one version behind**: walk through every missed version in order, not just the latest. Some migrations depend on prior ones
- **Changelog is missing or malformed**: refuse to run, tell the user to check that `CHANGELOG.md` exists at the skill root and is parseable. Don't guess
- **A repo in the registry no longer exists on disk**: skip it with a warning. User can clean up via `migrate` or by editing the registry
- **User runs upgrade during cron execution**: should be fine because upgrade doesn't touch knowledge files, but if the cron writes to config simultaneously, last write wins. Document this as a known quirk
