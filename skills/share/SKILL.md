---
name: share
description: Send codebase-rizz updates (new proposed patterns, new articles, ownership mismatches) out to configured channels — Gmail via Gmail MCP, Slack via Slack MCP, or a markdown fallback file if nothing is configured. Reads notification settings from rizz.config.json. Use when the user runs `share` manually, or when a cron invokes it at the end of a learn pipeline.
---

# share

Sends notifications for codebase-rizz events. The runtime sender, not the setup flow — for first-time configuration see `share/setup/SKILL.md`.

## Before doing anything

Resolve `<data_dir>` for the current repo via the registry lookup in `../_shared/paths.md`. If the lookup fails, tell the user to run `bootstrap` and stop.

## Inputs

- **event**: required. One of `learn_proposals_ready`, `new_article_published`, `ownership_mismatch_detected`. Other subskills pass this when they invoke share. When a user runs `share` manually, default to `learn_proposals_ready` and ask for confirmation
- **payload**: required. A structured summary of what to share (new pattern proposals, article metadata, mismatch findings). Format varies by event — see "Payload shapes" below

## Preflight

1. Read `<data_dir>/rizz.config.json`. If `notifications` is missing or `notifications.enabled` is `false`, stop silently and write a one-line skip entry to the log. This is not an error — the user has explicitly disabled notifications
2. Check `notifications.events[<event>]`. If the matching key is `false`, stop silently and log. Per-event toggles let the user mute specific noise without disabling everything
3. For each channel with `enabled: true`, verify the required MCP is reachable:
   - **Gmail**: check that a Gmail MCP tool (any tool whose name starts with `mcp__` and mentions gmail) is available in the current session. If missing, log the failure and continue to the next channel — don't block the whole send because one channel is down
   - **Slack**: same check for Slack MCP tools
4. If no channels are configured at all (both `gmail.enabled` and `slack.enabled` are false), fall through to the markdown fallback described below

## Formatting per channel

### Gmail (HTML email)

Gmail MCPs typically accept a `subject`, a recipient list, and a `body` (HTML or plain text). Build an HTML body with inline CSS — most mail clients strip external stylesheets:

```html
<div style="font-family: -apple-system, sans-serif; max-width: 600px;">
  <h2 style="color: #1a1a1a;"><event-specific heading></h2>
  <p style="color: #555;"><one-line summary></p>
  <table style="width: 100%; border-collapse: collapse;">
    <!-- one row per item in the payload -->
  </table>
  <p style="margin-top: 24px;">
    <a href="<link to the proposed file or article>"
       style="background: #1a1a1a; color: white; padding: 10px 18px;
              text-decoration: none; border-radius: 6px;">
      View details
    </a>
  </p>
  <p style="color: #999; font-size: 12px; margin-top: 32px;">
    Sent by codebase-rizz · <repo slug>
  </p>
</div>
```

Subject line is event-dependent:
- `learn_proposals_ready` → `[codebase-rizz] <N> new pattern proposals for <repo>`
- `new_article_published` → `[codebase-rizz] New article: <title>`
- `ownership_mismatch_detected` → `[codebase-rizz] Ownership mismatch in <repo>`

Send once per recipient in `notifications.channels.gmail.recipients`. If a send fails for one recipient, continue with the rest.

### Slack (Block Kit)

Slack MCPs typically accept a channel name and a list of blocks. Block Kit lets the message look like a real app, not a chat paste:

```json
{
  "blocks": [
    { "type": "header", "text": { "type": "plain_text", "text": "<event heading>" } },
    { "type": "context", "elements": [
      { "type": "mrkdwn", "text": "*codebase-rizz* · <repo slug> · <date>" }
    ]},
    { "type": "divider" },
    {
      "type": "section",
      "text": { "type": "mrkdwn", "text": "<one-line summary>" }
    },
    {
      "type": "section",
      "text": { "type": "mrkdwn", "text": "<bulleted list of items from payload>" }
    },
    {
      "type": "actions",
      "elements": [{
        "type": "button",
        "text": { "type": "plain_text", "text": "View details" },
        "url": "<link>"
      }]
    }
  ]
}
```

Post once per channel in `notifications.channels.slack.channels`. Continue on per-channel failure.

### Fallback (markdown file)

If both channels are disabled or both MCPs are unreachable, write a markdown file to `<data_dir>/shared/<event>-YYYY-MM-DD.md` with the same content as the email HTML (but rendered as markdown). Tell the user the path and suggest they copy-paste into their team's channel of choice.

The fallback is not a failure mode — it's a deliberate option for users who don't want to set up MCPs.

## Payload shapes

Callers pass a structured payload so `share` doesn't have to know anything about the event's content. Shapes:

- **`learn_proposals_ready`** — `{ proposals: [{ kind: "pattern" | "persona", title, one_liner, link }] }`
- **`new_article_published`** — `{ title, slug, teaser, link, word_count }`
- **`ownership_mismatch_detected`** — `{ mismatches: [{ assigned_to, actual_author, pr_link }] }`

Subskills that want to notify should build the payload explicitly and hand it to `share` — don't rely on `share` to go read files and infer the content.

## Logging

After each send attempt (success or failure, per recipient, per channel), append a line to `<data_dir>/proposed/.notification-log`:

```
2026-04-11T07:00:12Z  learn_proposals_ready  gmail  team@company.com  ok
2026-04-11T07:00:13Z  learn_proposals_ready  gmail  minh@company.com  ok
2026-04-11T07:00:14Z  learn_proposals_ready  slack  #engineering     failed: channel not found
```

This log is the user's window into whether notifications are actually going out. The next interactive skill invocation should surface recent failures.

## Reporting back

For each event handled:
- Which channels were tried
- Per-recipient success/failure
- Path to the fallback file if used
- Total count (e.g., "sent to 2 gmail recipients, 1 slack channel, 0 failures")

## What share does NOT do

- Does not decide what to say — it formats whatever payload the caller provides
- Does not retry failed sends — failures go to the log, the user decides what to do
- Does not modify `rizz.config.json` — setup is the only thing that writes config
