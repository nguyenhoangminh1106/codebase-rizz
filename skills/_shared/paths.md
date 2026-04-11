# Path resolution

Every subskill that reads or writes knowledge goes through this file. Do not hardcode `.codebase-rizz/` paths anywhere — the storage location is per-repo, decided at bootstrap time, and looked up at runtime.

## The global data directory

```
~/.codebase-rizz/
├── registry.json
└── repos/
    ├── <slug>/          # one dir per repo that chose "global" storage
    │   └── (same layout as .codebase-rizz/ in repo-local mode)
    └── ...
```

Created by `install.sh`. Never committed to any repo. This is where per-user (non-shared) knowledge lives for repos where the user chose global storage.

## The registry

`~/.codebase-rizz/registry.json` is the single source of truth for "which repos do I know about, and where is each one's data."

```json
{
  "version": 1,
  "repos": [
    {
      "path": "/Users/minh2/Documents/GitHub/paraform",
      "slug": "github.com-paraform-xyz-paraform",
      "remote_url": "git@github.com:paraform-xyz/paraform.git",
      "storage": "global",
      "data_dir": "/Users/minh2/.codebase-rizz/repos/github.com-paraform-xyz-paraform",
      "bootstrapped_at": "2026-04-10T17:00:00Z"
    },
    {
      "path": "/Users/minh2/Documents/GitHub/side-project",
      "slug": "github.com-nguyenhoangminh1106-side-project",
      "remote_url": "git@github.com:nguyenhoangminh1106/side-project.git",
      "storage": "repo-local",
      "data_dir": "/Users/minh2/Documents/GitHub/side-project/.codebase-rizz",
      "bootstrapped_at": "2026-04-11T09:00:00Z"
    }
  ]
}
```

## Slug derivation

Slugs are derived from the repo's remote URL so two different repos named `paraform` (one a fork) don't collide.

1. Read `git config --get remote.origin.url` from the repo
2. Normalize to host + path form:
   - `git@github.com:owner/repo.git` → `github.com/owner/repo`
   - `https://github.com/owner/repo.git` → `github.com/owner/repo`
   - `https://gitlab.com/group/sub/repo` → `gitlab.com/group/sub/repo`
3. Lowercase it
4. Strip trailing `.git`
5. Replace `/` with `-` to make it a valid directory name: `github.com-owner-repo`

Example: `git@github.com:paraform-xyz/paraform.git` → `github.com-paraform-xyz-paraform`

If the repo has no remote (fresh `git init`), fall back to the parent dir name with a `local-` prefix: `local-my-experiment`. Warn the user that slugs for remote-less repos are fragile.

## Preflight — every skill runs this first

Every skill in the plugin (except `bootstrap`, `migrate`, and `upgrade`, which manage the registry itself) must run this preflight before doing anything else. Skills should reference this section rather than re-stating it in their own SKILL.md — keeping the logic in one place means one change here propagates everywhere.

Steps, in order:

1. **Verify the user is in a git repo.** Run `git rev-parse --show-toplevel`. If it fails, tell the user to `cd` into the repo they want to work on and stop
2. **Read the registry.** Open `~/.codebase-rizz/registry.json`. If it doesn't exist, tell the user to run `install.sh` (or `/plugin install codebase-rizz@codebase-rizz`) and stop
3. **Look up the current repo.** Find the entry in `registry.repos` where `path` matches the current repo path from step 1. If no match, tell the user to run `/codebase-rizz:bootstrap` first and stop
4. **Return `data_dir`** from the matching entry. Every file read/write in the subskill uses this as the base path
5. **Validate `data_dir` exists on disk.** If the registry points at a directory that has been deleted or moved, tell the user to run `/codebase-rizz:migrate` or edit the registry by hand. This catches corrupted state early

The preflight does NOT include the gh CLI check — that's a separate concern handled by `gh-preflight.md` and only runs for skills that actually call gh.

## Data directory layout

Inside `data_dir`, the layout is always the same regardless of storage mode:

```
<data_dir>/
├── rizz.config.json            # repo config: personas, trusted_reviewers, crons, etc.
├── personas/                   # one file per tracked engineer
│   └── <github-username>.md
├── patterns.md                 # team review rulebook (the knowledge base)
├── feature-ownership.md        # who is currently building what
├── articles/                   # weekly technical writeups from learn-from-codebase
│   └── YYYY-MM-DD-<slug>.md
└── proposed/                   # cron output awaiting human merge
    ├── patterns/               # new-pattern proposals from learn-from-pr-comments
    │   ├── YYYY-MM-DD.md
    │   ├── drift-YYYY-MM-DD.md          # from learn-patterns-drift
    │   ├── backfill-YYYY-MM-DD.md       # from backfill (skipped by auto-review)
    │   └── backfill-overflow-YYYY-MM-DD.md
    ├── personas/               # persona update proposals from learn-from-persona-code
    │   ├── <username>-YYYY-MM-DD.md
    │   └── <username>-backfill-YYYY-MM-DD.md
    ├── reconcile-YYYY-MM-DD.md # from track-reconcile (ownership mismatches)
    ├── .from-pr-comments-last-run      # timestamp marker, not a proposal
    ├── .from-persona-code-last-run
    ├── .backfill-state.json            # resumable state for interrupted backfills
    ├── .auto-review.lock               # prevents concurrent auto-review runs
    ├── .auto-review-log                # append-only JSON lines, one per decision
    ├── .auto-review-dry-run-YYYY-MM-DD.md
    ├── .auto-review-notify-queue.json  # handoff to share subskill
    └── .notification-log               # append-only log of share sends
```

So once you have `data_dir`, everything else is just appending subpaths.

**Notes on the hidden files** (anything starting with a dot):

- Files prefixed with `.` are **state**, not proposals. Skills manage them internally — users shouldn't edit them by hand
- Files prefixed with `backfill-` are **human-review-only**. The auto-review cron explicitly skips them regardless of mode
- `*-last-run` markers are ISO 8601 timestamps used by the learning crons to know "what's new since last time"
- `.auto-review-log` is append-only — never truncate or delete it unless you've also archived the content somewhere, because `rollback` depends on it to reverse past decisions

## What "storage: global" means

Files live under `~/.codebase-rizz/repos/<slug>/`. Not visible to other team members, not in git. Good for solo users and for trying the skill without committing to team adoption.

## What "storage: repo-local" means

Files live under `<repo-root>/.codebase-rizz/`. Committed to git (except `proposed/`), shared with the team. Good when the team has agreed to adopt the skill and share institutional knowledge through version control.

When storage is repo-local, add `.codebase-rizz/proposed/` to the repo's `.gitignore` — proposed content is ephemeral cron output until a human merges it.

## Switching storage later

If the user wants to move a repo from global to repo-local (or vice versa), they run the `migrate` subskill. Don't edit `registry.json` or move files by hand — migrate handles both atomically and preserves symlink-free data integrity.

## When multiple repos share the skill

The registry can hold unlimited entries. Each has its own `data_dir`, so knowledge never crosses. Crons iterate the registry to visit every repo in turn. If the user only wants crons to run for some repos, they can set `crons: {}` in that repo's `rizz.config.json` to disable all scheduled learning without uninstalling.
