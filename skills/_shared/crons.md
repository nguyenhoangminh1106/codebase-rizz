# Cron setup (macOS launchd)

codebase-rizz v1 targets macOS and uses **launchd user agents** as the cron mechanism. Every cron in `rizz.config.json.crons` is translated into one plist file in `~/Library/LaunchAgents/`. Bootstrap generates them and prints the `launchctl load` commands; the user runs the load themselves (we never silently touch system state).

Linux (crontab/systemd) and Windows (Task Scheduler) are not supported in v1.

## Permissions — read this first

Scheduled crons invoke `claude -p`, which runs in **non-interactive mode**. There is no user sitting in front of Claude to approve tool prompts. If the skill tries to run a `gh` command or write a file that hasn't been pre-approved, Claude silently auto-denies it and the cron produces zero useful output.

To make crons actually work, two things must be true:

1. **The plist's `claude -p` command uses `--permission-mode allowAll`.** This mode auto-denies anything not explicitly in the allow list — making the failure mode loud in logs instead of silent. The plist template below includes this flag
2. **`~/.claude/settings.json` contains the allow list** defined in `permissions.md`. Bootstrap writes this during the cron install step. If the user skipped that step or removed the rules later, the crons will silently fail

If a cron appears to run but nothing shows up in `<data_dir>/proposed/`, the first thing to check is `~/.claude/settings.json` — see `permissions.md` for the full allowlist that must be present.

## Why launchd instead of crontab

- Launchd is the native macOS way. crontab still works but is deprecated and has fewer debugging knobs
- Launchd plists give you per-job stdout/stderr log paths, which are invaluable when debugging "why didn't my cron run"
- User agents (under `~/Library/LaunchAgents`) don't need root, don't need a password, and survive reboots

## Plist template

For each key in `crons`, bootstrap generates a plist following this template. Example for `from_pr_comments` with cron expression `0 6 * * *`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.codebase-rizz.<slug>.from-pr-comments</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/env</string>
        <string>bash</string>
        <string>-c</string>
        <string>ulimit -n 2147483646; cd "<repo path>" &amp;&amp; claude -p "/codebase-rizz:learn-from-pr-comments" --permission-mode allowAll</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>6</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>/Users/<user>/.codebase-rizz/logs/<slug>/from-pr-comments.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/<user>/.codebase-rizz/logs/<slug>/from-pr-comments.err</string>

    <key>RunAtLoad</key>
    <false/>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
```

## Label naming

`com.codebase-rizz.<slug>.<cron-key>` — the slug is the same slug used by the data directory, so multiple repos get non-colliding labels. Each plist is unique per repo + per cron.

## File path

`~/Library/LaunchAgents/com.codebase-rizz.<slug>.<cron-key>.plist`

Bootstrap creates these files. To uninstall them manually:

```bash
launchctl unload ~/Library/LaunchAgents/com.codebase-rizz.<slug>.<cron-key>.plist
rm ~/Library/LaunchAgents/com.codebase-rizz.<slug>.<cron-key>.plist
```

## Cron key list

| Config key | Subskill | Default schedule | Default mode |
|---|---|---|---|
| `from_pr_comments` | `learn-from-pr-comments` | daily 6:00 | always on |
| `from_persona_code` | `learn-from-persona-code` | daily 6:15 | always on |
| `track_reconcile` | `track-reconcile` | daily 7:00 | always on |
| `share` | `share` | daily 8:00 | always on (drains `.notify-queue.json`) |
| `from_codebase` | `learn-from-codebase` | Sunday 9:00 | always on |
| `patterns_drift` | `learn-patterns-drift` | Sunday 9:30 | always on |
| `auto_review` | `learn-auto-review` | Sunday 10:00 | **opt-in** via `auto_review.mode` |

The five "always on" learning crons only write to `<data_dir>/proposed/` — they never touch knowledge files. The `share` cron is also always on but does no learning — it just drains the notification queue and delivers events to Gmail/Slack (or silently skips if notifications are disabled). `auto_review` is the only cron with permission to modify `patterns.md` and persona files, and only if the user has explicitly opted in. Bootstrap will not generate a launchd plist for `auto_review` unless `auto_review.mode` is `dry_run` or `on`.

Ordering: `share` runs after the daily learn crons but before the weekly ones so that any events queued by Monday-Friday learning runs get delivered that same morning. On Sundays, `share` at 8:00 delivers any remaining events from the previous week, then the weekly crons at 9:00/9:30/10:00 generate new content that will be delivered by Monday morning's 8:00 share run.

## Cron expression translation

Standard 5-field cron (`min hour dom mon dow`) maps to launchd's `StartCalendarInterval` dict. Only the fields that are specific numbers are included; wildcards are omitted:

| cron expression | StartCalendarInterval |
|---|---|
| `0 6 * * *` | `{ Hour: 6, Minute: 0 }` |
| `15 6 * * *` | `{ Hour: 6, Minute: 15 }` |
| `0 9 * * 0` | `{ Hour: 9, Minute: 0, Weekday: 0 }` |

For cron expressions with lists (`0,30 * * * *`) or step values (`*/5 * * * *`), generate multiple `StartCalendarInterval` dicts — launchd supports a list of dicts, firing the job whenever any dict matches. If a cron expression is too complex to translate cleanly, bootstrap should fall back to printing it for the user to paste manually into a crontab and warn that launchd can't represent it.

## Loading after generation

Bootstrap prints, verbatim, the commands the user needs to run:

```bash
# Load the new cron agents:
launchctl load ~/Library/LaunchAgents/com.codebase-rizz.<slug>.from-pr-comments.plist
launchctl load ~/Library/LaunchAgents/com.codebase-rizz.<slug>.from-persona-code.plist
launchctl load ~/Library/LaunchAgents/com.codebase-rizz.<slug>.track-reconcile.plist
launchctl load ~/Library/LaunchAgents/com.codebase-rizz.<slug>.from-codebase.plist
launchctl load ~/Library/LaunchAgents/com.codebase-rizz.<slug>.patterns-drift.plist
```

The user pastes these into their terminal. Bootstrap **does not** run them automatically — that would be a surprise modification to system state. Telling the user exactly what to run, and letting them decide, is the right UX tradeoff.

## Verifying a cron is loaded

```bash
launchctl list | grep codebase-rizz
```

Each loaded agent shows up with its label, PID (or `-` if not currently running), and last exit status.

## Logs

Per-cron stdout/stderr logs live under `~/.codebase-rizz/logs/<slug>/`. When a user wonders "why didn't my cron run," the first thing any other subskill should suggest is `tail ~/.codebase-rizz/logs/<slug>/<cron>.log`.

## Disabling a single cron

Two ways:

1. **Remove the key from `crons` in `rizz.config.json`** — the next time bootstrap runs, the plist is regenerated without that entry (bootstrap should unload the old agent before removing the file)
2. **Manually unload**:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.codebase-rizz.<slug>.<cron-key>.plist
   ```
   This stops the cron without deleting the file, so the next `launchctl load` re-enables it

## Disabling all crons for a repo

```bash
for plist in ~/Library/LaunchAgents/com.codebase-rizz.<slug>.*.plist; do
  launchctl unload "$plist"
  rm "$plist"
done
```

Or delete the repo from the registry via `migrate` → global → manual cleanup — the subskill should offer this as a graceful uninstall path.

## Caveats

- **Laptop sleep**: if your mac is asleep at the scheduled time, launchd defers the job. It will run when the machine wakes. If you need guaranteed-at-time execution, launchd is not the right tool — but for learning crons that are fine being late, this is usually what you want
- **First-run timing**: `RunAtLoad` is set to `false` in the template. Crons fire on their next scheduled slot, not immediately at load time. Users who want to verify the job works should run the subskill interactively once before trusting the cron
