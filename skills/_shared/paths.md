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

## The lookup function every subskill needs

Before any subskill reads or writes knowledge, it must resolve the `data_dir` for the current repo. Pseudocode:

```
1. Read ~/.codebase-rizz/registry.json. If it doesn't exist, tell the user to run install.sh.
2. Get the current repo path: `git rev-parse --show-toplevel`
   - If this fails, the user isn't in a git repo. Tell them and stop.
3. Look up the entry in registry.repos where path == current repo path.
   - If no match, the repo hasn't been bootstrapped. Tell the user to run `bootstrap`.
4. Return entry.data_dir. Every subsequent file read/write uses this as the base path.
```

Inside `data_dir`, the layout is always the same regardless of storage mode:

```
<data_dir>/
├── rizz.config.json
├── personas/
├── patterns.md
├── feature-ownership.md
├── articles/
└── proposed/
    ├── patterns/
    └── personas/
```

So once you have `data_dir`, everything else is just appending subpaths.

## What "storage: global" means

Files live under `~/.codebase-rizz/repos/<slug>/`. Not visible to other team members, not in git. Good for solo users and for trying the skill without committing to team adoption.

## What "storage: repo-local" means

Files live under `<repo-root>/.codebase-rizz/`. Committed to git (except `proposed/`), shared with the team. Good when the team has agreed to adopt the skill and share institutional knowledge through version control.

When storage is repo-local, add `.codebase-rizz/proposed/` to the repo's `.gitignore` — proposed content is ephemeral cron output until a human merges it.

## Switching storage later

If the user wants to move a repo from global to repo-local (or vice versa), they run the `migrate` subskill. Don't edit `registry.json` or move files by hand — migrate handles both atomically and preserves symlink-free data integrity.

## When multiple repos share the skill

The registry can hold unlimited entries. Each has its own `data_dir`, so knowledge never crosses. Crons iterate the registry to visit every repo in turn. If the user only wants crons to run for some repos, they can set `crons: {}` in that repo's `rizz.config.json` to disable all scheduled learning without uninstalling.
