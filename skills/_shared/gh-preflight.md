# GitHub CLI preflight

Every subskill that touches GitHub must pass this check before making any API call. Results are cached per session at `/tmp/codebase-rizz-gh-check-$USER` so the check runs once, not on every invocation.

## The 4 steps

Run them in order. Stop at the first failure and print the remediation verbatim — don't try to auto-fix or work around.

### 1. Is `gh` installed?

```bash
command -v gh >/dev/null 2>&1
```

If missing:

> GitHub CLI is required. Install it:
> - macOS: `brew install gh`
> - Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
> - Windows: `winget install --id GitHub.cli`
>
> Then come back and re-run.

### 2. Is the user logged in?

```bash
gh auth status
```

If not logged in:

> Log in to GitHub CLI with the scopes this skill needs:
> `gh auth login --scopes "repo,read:org"`
>
> Pick HTTPS when prompted and paste the one-time code in your browser.

### 3. Is the configured repo accessible?

Resolve the current repo's `data_dir` via the registry lookup (see `paths.md`), then read `<data_dir>/rizz.config.json` and extract the `repo` field (owner/name slug). Then:

```bash
gh repo view <owner>/<repo> >/dev/null
```

If this fails:

> Can't reach `<owner>/<repo>`. Either the slug in `<data_dir>/rizz.config.json` is wrong, or your GitHub account doesn't have access. Check the slug first, then ask a repo admin to add you if the slug is right.

### 4. Cache the pass

On success, write a marker:

```bash
touch /tmp/codebase-rizz-gh-check-$USER
```

Subsequent subskill calls in the same session check for this file first and skip the preflight if it exists. The marker gets wiped on reboot, so a new session always re-verifies.

## When to re-run

- If any step failed previously and the user says they fixed it
- If the user changed the repo slug in `<data_dir>/rizz.config.json`
- If a gh call inside a subskill returns a permission error — the token may have lost a scope; re-run the preflight and retry once
