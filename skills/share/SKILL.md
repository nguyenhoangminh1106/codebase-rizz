---
name: share
description: Drain the notification queue and deliver pending events (new articles, auto-review summaries, ownership mismatches, etc.) via configured channels — Gmail MCP, Slack MCP, or a markdown fallback. Runs as a daily cron that processes everything queued by other skills since the last run. Can also be invoked manually to force an immediate drain. Never blocks, retries up to 3 times per event, drops stale events after 30 days, and logs every delivery attempt.
---

# share

The notification dispatcher. Reads `<data_dir>/proposed/.notify-queue.json`, delivers each queued event through the channels the user configured in `rizz.config.json`, and removes events from the queue on success. Retries failures up to 3 times, then drops and logs.

For the queue format, producer rules, and event payloads, see `../_shared/notify-queue.md`. This subskill is the **consumer** — producers are other skills that append events to the queue (currently `learn-from-codebase` and `learn-auto-review`).

For first-time notification setup (which channels, which recipients, which events), see `share-setup`.

## Before doing anything

Run the preflight from `../_shared/paths.md` to resolve `<data_dir>` for the current repo. When running as a cron across multiple repos, iterate every registry entry and drain each repo's queue independently.

## Schedule

Default: daily at 8:00am. Configured via `crons.share` in `rizz.config.json` and loaded as a launchd user agent by bootstrap. See `../_shared/crons.md`.

Unlike the learning crons, share is always-on — it has no `auto_review`-style opt-in mode. If the user doesn't want notifications, they set `notifications.enabled: false` in config (or leave it off at bootstrap) and the cron becomes a silent no-op that drains nothing.

## The drain procedure

This is the core loop. Every run, from start to finish.

1. **Take the queue lock.** Create `<data_dir>/proposed/.notify-queue.lock`. If it already exists and is younger than 60 seconds, wait up to 5 seconds then bail (another `share` run is in progress). If the lock is older than 60 seconds, treat it as stale (crash recovery) and proceed
2. **Read the config.** Load `<data_dir>/rizz.config.json`. If `notifications.enabled` is false or missing, the user has notifications turned off. Do NOT drop the queue — events stay in place so that if the user re-enables notifications later, the backlog still gets delivered. Just release the lock and exit
3. **Read the queue.** Load `<data_dir>/proposed/.notify-queue.json`. If it doesn't exist or is empty, release the lock and exit cleanly — nothing to do
4. **Drop stale events.** For every event with `queued_at` older than 30 days, remove it from the queue and append a failure-log entry with `reason: "stale, dropped after 30 days"`. Stale events indicate the user has been away too long to care about old notifications
5. **Process remaining events in order.** For each event:
   - Read `notifications.events[<event.event>]` from config
     - If missing or false → silently remove the event from the queue. The user has muted this event type. Log nothing, no retry
     - If true → proceed to delivery
   - Determine enabled channels (`notifications.channels.gmail.enabled`, `notifications.channels.slack.enabled`)
   - For each enabled channel, attempt delivery (see "Delivery" below). Track per-channel success/failure
   - **If all enabled channels succeeded** → remove this event from the queue. Log each successful delivery to `<data_dir>/proposed/.notification-log`
   - **If any enabled channel failed** → increment `event.retry_count`
     - If `retry_count >= 3` → drop the event, append failure-log entry, log each per-channel failure for the record
     - Otherwise → leave the event in the queue with the incremented retry count. The next `share` run will retry
   - **If no channels are enabled** → fall through to the markdown fallback (see below). Treat as success, remove from queue
6. **Atomic-write the updated queue.** Temp + rename
7. **Release the lock**
8. **Print the run summary** — how many events delivered, how many dropped (stale or max retries), how many still in queue for later

## Delivery per channel

### Gmail (via Gmail MCP)

Detect available Gmail MCP tools by looking for any tool whose name starts with `mcp__` and contains `gmail`. If none found, mark Gmail as unreachable for this run, continue to other channels (but this event's delivery counts as a failure for the Gmail channel, contributing to the retry count if no other channel succeeds either).

Build an HTML body with inline CSS — most mail clients strip external stylesheets:

```html
<div style="font-family: -apple-system, sans-serif; max-width: 600px;">
  <h2 style="color: #1a1a1a;"><event-specific heading></h2>
  <p style="color: #555;"><one-line summary></p>
  <!-- event-specific content block -->
  <p style="margin-top: 24px;">
    <a href="<link>"
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

Subject lines by event type:
- `new_article_published` → `[codebase-rizz] New article: <title>`
- `auto_review_complete` → `[codebase-rizz] Auto-review: merged <N>, skipped <M>`
- `ownership_mismatch_detected` → `[codebase-rizz] Ownership mismatch in <repo>`
- `learn_proposals_ready` → `[codebase-rizz] <N> new proposals for <repo>`

Send once per recipient in `notifications.channels.gmail.recipients`. Per-recipient failures are per-recipient — one bad address doesn't fail the whole Gmail channel. A channel is "successful" if at least one recipient succeeded.

Emails send from the user's own authenticated Gmail address. Recipients see the user as the sender.

### Slack (via Slack MCP)

Detect Slack MCP the same way — look for `mcp__*slack*` tools. If none, Slack channel is unreachable for this run.

Build a Block Kit payload:

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
      "text": { "type": "mrkdwn", "text": "<event-specific body>" }
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

Post once per channel in `notifications.channels.slack.channels`. Per-channel failures are per-channel — if `#engineering` is archived but `#codebase-rizz` works, the Slack channel is successful for this event.

Messages post as the official Claude Slack app (set up via `share-setup` and `../_shared/mcp-install.md`).

### Fallback (markdown file)

If **no channels are configured** (both `gmail.enabled` and `slack.enabled` are false), write the event's content to `<data_dir>/shared/<event_type>-<YYYY-MM-DD>-<id>.md` and treat as delivered.

The fallback is not triggered when channels ARE configured but both fail — that's a real failure and retries. The fallback is only for users who deliberately chose not to set up MCPs.

## Event-specific message content

For each event type, build the content that goes inside the message body. The schema is defined in `../_shared/notify-queue.md` under "Event payloads"; the content below describes what the reader sees.

### `new_article_published`

Render the **full article inline** — readers should not have to leave the message to read it.

1. Read the markdown file at `payload.path`
2. **Heading**: `📄 <title>` (drop the "New article:" prefix — the heading is the title)
3. **Byline** (context block in Slack, muted `<p>` in Gmail): `codebase-rizz · <repo slug> · <date> · <word_count> words · ~<minutes> min read`
4. **Body**: the rendered article:
   - **Gmail**: convert markdown to inline-styled HTML. Headings → `<h2>/<h3>`, paragraphs → `<p>`, lists → `<ul>/<ol>`, fenced code → `<pre><code>`, blockquotes → `<blockquote>`, preserve bold/italic/inline-code. Use the same outer container/inline CSS as the generic template
   - **Slack**: emit one Block Kit block per top-level markdown element. Headings → `section` with `*bold*` mrkdwn. Paragraphs → `section` mrkdwn (convert `**x**` → `*x*`, keep `_italic_`, inline code as `` `x` ``). Fenced code → `section` wrapping the code in triple backticks. Blockquotes → `section` with each line prefixed by `> `. Lists → single `section` with `•` bullets (or `1.` for ordered). Slack caps at 50 blocks and ~3000 chars per text field — if the article exceeds either, split long paragraphs across multiple sections and, if still over budget, post the overflow as threaded replies to the first message rather than truncating
5. **Footer link**: `payload.path` rendered as a secondary "View source file" button/link — optional, since the article body is already in the message

The teaser (`payload.teaser`) is still used for the email preview line / Slack notification snippet, but it is not the body of the message.

### `auto_review_complete`

- **Heading**: `🤖 Auto-review ran on <date>`
- **One-line summary**: `Merged <N> patterns, rejected <M> items, <K> skipped for your review.`
- **Body**: Bullet list with counts and one sentence about what to do next (e.g., "Review `<data_dir>/proposed/.auto-review-log` to see what changed. Run `/codebase-rizz:rollback` to reverse any bad merge.")
- **Link**: `payload.log_path` — path to the audit log

### `ownership_mismatch_detected`

- **Heading**: `⚠️ Ownership mismatch in <repo>`
- **One-line summary**: `Found <N> mismatch(es) between assignments and actual PR authors.`
- **Body**: List each mismatch with PR link, assigned engineer, actual author. Suggest running `/codebase-rizz:track-assign` to correct
- **Link**: First mismatch's PR link, or the feature-ownership.md path

### `learn_proposals_ready`

- **Heading**: `📋 <N> new proposals ready to review`
- **One-line summary**: `<N> new patterns and/or persona updates are waiting in your proposed/ folder.`
- **Body**: Breakdown (X patterns, Y persona updates) with one-liner per item from the payload
- **Link**: The proposed folder path

## Logging

Two log files, both append-only:

**`<data_dir>/proposed/.notification-log`** — one line per delivery attempt (success or failure):

```
2026-04-11T08:00:12Z  new_article_published  gmail  team@company.com  ok
2026-04-11T08:00:13Z  new_article_published  slack  #engineering  failed: channel_not_found
2026-04-11T08:00:13Z  new_article_published  slack  #codebase-rizz  ok
```

**`<data_dir>/proposed/.notify-failure-log`** — one JSON line per event that was dropped (max retries or stale):

```json
{"ts":"2026-04-14T08:00:12Z","event_id":"art-2026-04-11-crm-quick-actions","event_type":"new_article_published","reason":"max retries exceeded","last_error":"Gmail MCP timed out after 30s","retry_count":3}
```

Both logs are user-facing diagnostics. The next time a user runs anything interactive, surface the last few failure-log entries if they exist.

## Manual invocation

When a user runs `/codebase-rizz:share` interactively (not via cron), the behavior is identical to the cron: drain the queue, process in order, log everything. The difference is that interactive runs also print the human-readable summary to stdout:

```
Drained 3 events from the queue:
  ✓ new_article_published (art-2026-04-11-crm-quick-actions) → gmail (2), slack (1)
  ✓ auto_review_complete (ar-2026-04-13-10-00) → gmail (2), slack (1)
  ✗ ownership_mismatch_detected (om-2026-04-11-07-00) → gmail failed (recipient bounced), slack ok

2 succeeded, 1 retrying (retry 1/3). 0 events still queued.
```

## What share does NOT do

- **Does not decide what to notify about.** Producers decide by appending to the queue. Share just delivers whatever is there
- **Does not modify `rizz.config.json`.** Setup is the only skill that writes config
- **Does not retry in a tight loop.** One attempt per cron run. 3 failed runs = event dropped
- **Does not deliver events in parallel.** Sequential processing, per event, per channel. Keeps logs clean and MCP rate limits predictable
- **Does not "catch up" stale events aggressively.** 30-day cutoff is a hard drop, not a last-ditch delivery attempt
- **Does not touch the markdown fallback when channels are configured.** If Gmail and Slack are both down for real, the event retries until max retries, then goes to the failure log — not to a fallback file. Fallback is only for users who deliberately skipped MCP setup

## Failure modes

- **Queue file missing** — nothing to drain, exit cleanly. Don't create an empty file; the producer will create it when it has something to queue
- **Queue file corrupt (invalid JSON)** — do NOT truncate or overwrite. Move the corrupt file aside (`.notify-queue.json.corrupt-<ts>`), write a fresh empty queue, log a failure-log entry pointing at the backup, and exit. The user can inspect the backup and manually recover
- **Lock file stuck** — if the lock is older than 60 seconds, assume crash recovery and proceed. Log a warning
- **Config file missing** — tell the user to run `/codebase-rizz:bootstrap`, exit
- **No MCPs available and no fallback path set** — treat the current run as a total failure, don't remove any events from the queue, log a clear diagnostic. The user fixes their setup and the next run succeeds
