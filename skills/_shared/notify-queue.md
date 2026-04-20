# Notification queue

The notification queue is the file-based handoff between skills that want to notify something (producers) and the `share` skill that actually delivers notifications (consumer). It exists because plugin skills can't call each other directly — but they can read and write shared files.

Instead of each producer skill figuring out how to talk to Gmail and Slack, they just append an event to `<data_dir>/proposed/.notify-queue.json`. A daily `share` cron reads the queue, delivers each event through whichever channels the user configured, and removes the event on success (or drops it with a failure log after 3 retries).

This file is the single source of truth for the queue format. If you add a new event type or a new producer, update this file first.

## Location

```
<data_dir>/proposed/.notify-queue.json
```

- Global mode: `~/.codebase-rizz/repos/<slug>/proposed/.notify-queue.json`
- Repo-local mode: `<repo-root>/.codebase-rizz/proposed/.notify-queue.json`

The `.` prefix keeps it as state (not a proposal the user reviews). Every skill that writes to it must use atomic-rename (temp + mv) because producers and the consumer may run concurrently — the cron doesn't coordinate with the learn crons.

## Shape

```json
{
  "version": 1,
  "events": [
    {
      "id": "art-2026-04-11-crm-quick-actions",
      "queued_at": "2026-04-11T09:03:12Z",
      "event": "new_article_published",
      "retry_count": 0,
      "payload": {
        "title": "CRM Quick Actions: Why We Built the Menu as a Store",
        "slug": "crm-quick-actions",
        "path": "/Users/minh2/.codebase-rizz/repos/github.com-paraform-xyz-paraform/articles/2026-04-11-crm-quick-actions.md",
        "teaser": "There was a Slack thread on April 10 that's worth reading before you open any of the CRM code...",
        "word_count": 2841
      }
    },
    {
      "id": "ar-2026-04-13-10-00",
      "queued_at": "2026-04-13T10:00:14Z",
      "event": "auto_review_complete",
      "retry_count": 1,
      "payload": {
        "merged": 3,
        "rejected": 8,
        "skipped": 4,
        "log_path": "/Users/minh2/.codebase-rizz/repos/github.com-paraform-xyz-paraform/proposed/.auto-review-log"
      }
    }
  ]
}
```

## Field meanings

### Top-level

- **`version`** (integer, required) — schema version of the queue file itself. Currently `1`. If the schema ever changes incompatibly, bump this and `share` must handle older versions with a migration
- **`events`** (array, required) — ordered list of events awaiting delivery. Oldest first. The consumer processes them in order and removes each one as it succeeds

### Per-event

- **`id`** (string, required) — a stable identifier for deduplication. A producer that would write the same event twice should notice the ID is already in the queue and skip the second write. Format is producer-specific, but should be unique enough that no two events collide:
  - Article events: `art-<YYYY-MM-DD>-<slug>`
  - Auto-review events: `ar-<YYYY-MM-DD>-<HH-MM>`
  - Future producers: use a similar prefix + timestamp + discriminator
- **`queued_at`** (ISO 8601 UTC timestamp, required) — when the producer wrote this event. Used for sorting, debugging, and deciding whether a stale event should be dropped (see "Stale events" below)
- **`event`** (string, required) — the event type. Must match a key in `notifications.events` in `rizz.config.json`. Currently supported types:
  - `new_article_published`
  - `auto_review_complete`
  - `ownership_mismatch_detected`
  - `learn_proposals_ready`
- **`retry_count`** (integer, required) — how many delivery attempts have already failed for this event. Starts at `0`. Incremented on each failed delivery. Once it hits `3`, the consumer drops the event and writes a failure-log entry
- **`payload`** (object, required) — event-specific data that the consumer uses to build the Gmail/Slack message. Shape depends on `event` (see below)

## Event payloads

### `new_article_published`

```json
{
  "title": "Article title exactly as rendered",
  "slug": "article-slug",
  "path": "<absolute path to the article markdown file>",
  "teaser": "First 1-2 sentences of the article for use in the message",
  "word_count": 2841
}
```

Producer: `learn-from-codebase` after writing an article.

Consumer behavior: read the markdown file at `payload.path` and render the **full article body** inline in the message — no truncation, no teaser-only preview. The reader should be able to read the whole piece without leaving the notification. In Gmail, convert the markdown to inline-styled HTML (headings, paragraphs, lists, code fences, blockquotes). In Slack, emit one Block Kit section per markdown element and split across threaded replies if the article exceeds Slack's 50-block / 3000-char-per-field limits. Keep the "View source file" button at the end for readers who want to open the `.md` locally, but the button is now a secondary affordance — the article itself is the message.

### `auto_review_complete`

```json
{
  "merged": 3,
  "rejected": 8,
  "skipped": 4,
  "log_path": "<absolute path to .auto-review-log>"
}
```

Producer: `learn-auto-review` after each run.

Consumer behavior: build a summary message (`"Merged 3 patterns, rejected 8 items, 4 skipped for your review"`) with a link to the audit log path and a mention of the `/codebase-rizz:rollback` command for reverting any bad merge.

### `ownership_mismatch_detected`

```json
{
  "mismatches": [
    {
      "assigned_to": "anthnykr",
      "actual_author": "minh2",
      "pr_link": "https://github.com/..."
    }
  ]
}
```

Producer: `track-reconcile` when it finds assignments that disagree with merged PRs.

Consumer behavior: list each mismatch with PR links, suggest the user run `/codebase-rizz:track-assign` to correct ownership.

### `learn_proposals_ready`

```json
{
  "proposals": [
    { "kind": "pattern", "title": "...", "one_liner": "...", "link": "<path>" }
  ]
}
```

Producer: none of the existing skills currently emit this — it's reserved for future use (e.g., a skill that wants to actively nudge the user when pending-merge count crosses a threshold).

## Producer rules

Every skill that appends to the queue must follow these rules so the consumer sees consistent data:

1. **Take a lock first.** Before reading the queue to append, take a lock at `<data_dir>/proposed/.notify-queue.lock`. Release on exit. If the lock is already present, wait briefly (up to 2 seconds), then bail with a log line. Never skip the lock — two producers writing simultaneously will corrupt the JSON
2. **Read, append, atomic-write.** Load the current queue, add the new event, write to `.notify-queue.json.tmp`, rename over the real file. Never truncate and rewrite in place
3. **Check for dupes.** Before appending, look for an existing event with the same `id`. If found, do nothing — don't increment anything, don't re-queue. This covers the case where a producer runs twice in quick succession (e.g., launchd fires a catch-up run the same day as a normal run)
4. **Bounded queue.** If the queue already has more than 100 events, producers should **not** append new ones — the consumer is broken or disabled, and adding more events just makes the problem worse. Log a warning and skip. The consumer will drain the queue eventually and new events can queue again
5. **Never mutate existing events.** Producers only append. Only the consumer edits or removes events

## Consumer rules (the `share` skill)

The `share` cron drains the queue exactly once per run. Its logic:

1. Take the notify-queue lock
2. Read the queue
3. For each event in order:
   a. Check `notifications.enabled` in config. If false, drop the entire queue and return (user has disabled notifications; the queue should not grow)
   b. Check `notifications.events[<event_type>]`. If false, remove this event from the queue silently (the user has muted this event type; not a failure, just a policy)
   c. Check `retry_count`. If already `>= 3`, drop the event with a failure-log entry and continue
   d. For each enabled channel (gmail, slack), try to deliver. Track per-channel success/failure
   e. If **all configured channels succeeded**, remove the event from the queue
   f. If **any channel failed**, increment `retry_count` and leave the event in the queue. The next `share` cron run will retry
   g. If **no channels are configured at all**, write the message to the markdown fallback file and remove the event (fallback is considered a successful delivery)
4. Atomic-write the updated queue
5. Release the lock
6. Log a summary: delivered N events, dropped M events, K events remain in queue

## Stale events

If the queue has events older than **30 days**, the consumer drops them with a failure-log entry and does not attempt delivery. This prevents a stuck queue from snowballing over a year-long laptop-off period. 30 days is enough for normal vacations; if you're gone longer than that, you probably don't want stale "here's what we merged a month ago" messages anyway.

## Failure log

When the consumer drops an event (either from 3 failed retries or from being stale), it appends one JSON line to `<data_dir>/proposed/.notify-failure-log`:

```json
{"ts":"2026-04-14T08:00:12Z","event_id":"art-2026-04-11-crm-quick-actions","event_type":"new_article_published","reason":"max retries exceeded","last_error":"Gmail MCP timed out after 30s","retry_count":3}
```

The user can tail this log when they notice notifications aren't arriving. If it's full of "Gmail MCP timed out" errors, they know exactly what to fix.

## Concurrency safety

**Two producers simultaneously**: the lock serializes them. At most one producer touches the file at a time

**Producer and consumer simultaneously**: the lock serializes them. Either the producer finishes appending and the consumer sees the new event, or the consumer finishes draining and the producer sees an empty queue to append to. No interleaving, no lost events

**Multiple consumers simultaneously**: shouldn't happen (only one `share` cron exists per repo), but the lock handles it if it does

**Crash mid-write**: atomic rename guarantees the file is either the old version or the new version, never a half-written corruption. The lock file may be orphaned after a crash; the lock acquisition logic should check if the lock is older than 60 seconds and treat that as stale
