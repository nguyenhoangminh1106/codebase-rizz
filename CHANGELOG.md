# Changelog

Every versioned change to codebase-rizz lives here. The `upgrade/` subskill parses this file to decide what migrations to run when a user upgrades from an older version. Because of that, the structure below is load-bearing — **don't freeform this file**.

## Format

Each version entry uses this exact shape:

```markdown
## v<N>

- **scope**: this_repo | all_repos
- **title**: one-line summary
- **new_config_keys**:
  - `key.path` (default: `<value>`) — short description
- **new_subskills**:
  - `<subskill path>` — one-line description
- **new_notification_events**:
  - `<event_key>` — short description
- **migration**: one-paragraph description of what upgrade should do for users on the previous version
- **details**: |
    Multi-paragraph human-readable explanation of what's in this version and why it matters.
```

Fields that don't apply to a version are omitted (not set to `null` or empty).

- `scope` = `this_repo` means the upgrade touches only the current repo's config. User runs `upgrade` from inside the repo they want to migrate
- `scope` = `all_repos` means the upgrade is skill-wide and should fan out across every repo in the registry, asking the user per repo

---

## v3

- **scope**: all_repos
- **title**: Restructure as a Claude Code plugin with per-skill slash commands
- **new_config_keys**:
  - `version` (new default: `3`) — bumped to track the restructure
- **new_subskills**: (none — restructure only, no new functionality)
- **migration**: The skill source layout changed from a single nested skill with subskill directories to a plugin with one flat skill per directory under `skills/`. User data and config are **unchanged** — everything in `~/.codebase-rizz/` and in repo-local `.codebase-rizz/` directories keeps working without modification. Only the skill code on disk at `~/.claude/skills/codebase-rizz/` (or wherever the previous install placed it) needs to be replaced. The recommended replacement path is `/plugin install codebase-rizz@nguyenhoangminh1106`. The `install.sh` fallback script copies the new layout into `~/.claude/plugins/codebase-rizz/`. After the new plugin is installed, `upgrade` should only bump the `version` field in each repo's `rizz.config.json` from 2 to 3 — no config keys are added or removed. Old nested-path slash commands (if any users were invoking them) are replaced with new flat slash commands under the `/codebase-rizz:*` namespace.
- **details**: |
    v3 is a **structural release**. Nothing about what the skill does has
    changed — all the learning, personas, review, backfill, auto-review, and
    notification features from v2 are intact. What changed is how Claude Code
    exposes the skill.

    In v1 and v2, the skill was a single skill with nested SKILL.md files for
    each subskill. Claude Code's slash command system doesn't actually expose
    nested SKILL.md files as invokable commands — that was my misunderstanding
    of the skill directory format. Users could only invoke `/codebase-rizz`
    as a single slash command and rely on natural-language dispatch to pick
    a subskill, which was fragile and unpredictable.

    v3 fixes this by restructuring the repo as a **Claude Code plugin** with
    one flat skill per directory. Every capability is now independently
    invokable via a `/codebase-rizz:<name>` slash command:
      /codebase-rizz:bootstrap
      /codebase-rizz:review
      /codebase-rizz:code-like-auto
      /codebase-rizz:learn-from-pr-comments
      /codebase-rizz:backfill
      /codebase-rizz:upgrade
      (and so on)

    There are 17 slash commands in total.

    Reference material that used to live under `references/` is now in
    `skills/_shared/` (prefixed with underscore so Claude Code ignores it as
    a skill candidate). Paths in every SKILL.md were updated.

    The cross-skill delegation that existed in v1/v2 (e.g. bootstrap
    "delegating" to share-setup) no longer exists — skills in a plugin are
    siblings, not parent/child. Where delegation was needed, the pattern is
    now: the first skill finishes, then tells the user to run the next slash
    command. For inter-skill data passing (e.g. auto-review wanting to
    notify via share), the pattern is a file-based handoff queue instead of
    a direct call.

    No user data migrates. Your personas, patterns, articles, and config are
    all preserved exactly as they were. `/codebase-rizz:upgrade` just bumps
    the `version` field in each repo's config from 2 to 3 and prints a
    one-liner confirming the structural migration is done.

---

## v2

- **scope**: all_repos
- **title**: Opt-in auto-review cron and rollback
- **new_config_keys**:
  - `version` (default: `2`) — schema version of this config file
  - `auto_review.mode` (default: `"off"`) — one of `off`, `dry_run`, `on`
  - `auto_review.max_merges_per_run` (default: `5`) — hard cap per cron run
  - `crons.auto_review` (default: `"0 10 * * 0"`) — Sunday 10am
- **new_subskills**:
  - `learn/auto-review` — opt-in cron that reviews proposals and merges qualifying ones
  - `rollback` — undo a specific auto-review merge via the audit log
  - `upgrade` — this file's consumer; per-repo and all-repos migration runner
- **new_notification_events**:
  - `auto_review_complete` — fires after each auto-review run with a merge/reject/skip summary
- **migration**: For each repo in the registry, ask the user the three-option auto-review prompt (off / dry_run / on). Default to `off` if the user doesn't answer. If they pick `dry_run` or `on`, generate the `auto_review` launchd plist and print the `launchctl load` command. Write `version: 2` and the new `auto_review` block into the repo's `rizz.config.json`. Also add the new notification event key to `notifications.events` if the user already has notifications configured — default the new event to `true` if they're on notifications, since the whole point is they wanted to be told things.
- **details**: |
    v2 introduces the only part of codebase-rizz that can modify your knowledge
    base without direct approval each time — and it's strictly opt-in.

    The existing learn crons (from-pr-comments, from-persona-code, etc.) still
    only write to the `proposed/` folder. They never touch `patterns.md` or the
    persona files. That guarantee is unchanged.

    The new `learn/auto-review` cron is a separate weekly job that reads
    pending proposals and has Claude decide which ones are clearly good enough
    to merge without human review. Clearly-bad items get rejected (permanently
    removed from `proposed/`). Ambiguous items stay in `proposed/` for manual
    review. Only a small fraction of proposals actually auto-merge — the bar
    is strict (3+ evidence pieces, 2+ trusted reviewers, clear *why*, high
    Claude confidence, not a duplicate, not an amendment to an existing rule).

    Every auto-merge is logged in `proposed/.auto-review-log` with the exact
    diff that was applied. The new `rollback` subskill reads that log and lets
    you reverse any merge with a single command.

    Dry-run mode is strongly recommended as a first step. It runs Claude's
    review pipeline but writes decisions to a log instead of touching files.
    Use it for a week or two to see what Claude would merge, then flip to `on`
    once you trust its judgment.

---

## v1

- **scope**: this_repo
- **title**: Initial release
- **details**: |
    First shipped version. Includes:

    - Bootstrap (with storage mode choice: global or repo-local)
    - Generate (code-like-auto + code-like-person)
    - Review (diff against patterns.md + persona taste)
    - Learn crons: from-pr-comments, from-persona-code, from-codebase, patterns-drift
    - Track: assign + reconcile
    - Migrate (move a repo's data between storage modes)
    - Share + share/setup (notifications via Gmail/Slack MCP, markdown fallback)
    - Local cron setup via launchd (macOS)
    - Registry-driven path resolution so no subskill hardcodes `.codebase-rizz/`

    v1 does not have a `version` field in config. Upgrade treats any config
    without a `version` key as v1.
