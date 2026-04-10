---
name: codebase-rizz-share-setup
description: Interactive first-time setup for codebase-rizz notifications. Detects which notification MCPs (Gmail, Slack) are available in the current Claude Code session, explains the sender model for each, instructs the user how to install any missing MCP server, and writes the notifications block to rizz.config.json. Invoked automatically at the end of bootstrap, or manually when the user wants to reconfigure.
---

# share / setup

Interactive setup for notifications. This subskill writes config; the runtime `share/` subskill reads it. Split so that each cron invocation can skip the setup logic entirely and just do the send.

## Before doing anything

Resolve `<data_dir>` for the current repo via the registry lookup in `../../references/paths.md`. If the lookup fails, tell the user to run `bootstrap` first.

## Step 1 — Explain what's happening

Print a short intro before asking anything:

> codebase-rizz can send you notifications when new patterns are proposed, new articles are written, or ownership mismatches are detected. I'll walk you through setting this up. You can skip any channel you don't want — and skip the whole thing if you'd rather not get notifications.

## Step 2 — Detect available MCPs

Look at the tool list in the current session. Check for tools matching any of these patterns:

- Gmail-adjacent: tool names containing `gmail`, `google_mail`, or `mail`
- Slack-adjacent: tool names containing `slack`

For each match, note:
- The tool name
- Whether it looks like a "send" tool (vs. "read" or "authenticate") — prefer tools with `send`, `post`, `create`, `message` in their name

If you find no Gmail tools, mark Gmail as "not installed." Same for Slack. **Don't fail yet** — we still want to offer to install them.

## Step 3 — Walk through each channel

### Gmail

Print:

> **Gmail**
> - Sender: messages will be sent **from your own Gmail address** (whichever account you authenticate the MCP with). Recipients see your name.
> - Requires: a Gmail MCP server installed and authenticated in your local Claude Code

Then:

- If Gmail MCP is detected: "I can see a Gmail MCP is already installed. Do you want to use it for notifications? (y/n)"
  - If yes → ask for recipient email addresses (comma-separated, at least one)
  - If no → mark Gmail channel as disabled, move on
- If Gmail MCP is not detected: "I don't see a Gmail MCP in this session. Do you want to set one up? (y/n)"
  - If yes → print the install instructions from `../../references/mcp-install.md` (section: Gmail). Ask the user to run the install and come back. Stop this subskill — the user re-runs it after installing. Don't try to half-finish
  - If no → mark Gmail channel as disabled, move on

### Slack

Print:

> **Slack**
> - Sender: messages post **as the Claude Slack app** in your workspace, using the connection between your Slack account and your Claude account. Recipients see them as coming from "Claude," not from you personally and not from a custom bot
> - Requires: a workspace admin to have installed the Claude app from the Slack Marketplace, your Slack ↔ Claude connection in the App Home tab, the `slack@claude-plugins-official` plugin installed in Claude Code, and the Claude app invited to any channel you want posts to go to
> - See `../../references/mcp-install.md` for the full setup flow

Then follow the same detect / already-installed / not-installed flow as Gmail:
- Detected → ask y/n → collect channel list (with or without `#`)
- Not detected → offer install instructions, pause if yes

### Neither

If the user declined both channels, confirm: "OK, I'll configure the markdown fallback instead. The skill will write proposed updates to `<data_dir>/shared/` and you can copy-paste them into whatever channel you like."

## Step 4 — Event toggles

For whichever channels are enabled (or if only fallback is enabled), ask which events should fire notifications:

> Which events do you want notifications for?
>
> 1. **Learn proposals ready** (new patterns or persona updates) — recommended: yes
> 2. **New article published** — recommended: yes
> 3. **Ownership mismatches** (track/reconcile flagged something) — recommended: no (noisy)
>
> Answer y/n for each, or press enter to accept the recommendations.

Record the choices.

## Step 5 — Write the config

Read the existing `<data_dir>/rizz.config.json`, add or update the `notifications` block to match what was collected, write it back. Do not clobber other keys in the file.

The shape is defined in `../../references/config-schema.md` under "Notifications".

## Step 6 — Confirm and test

Tell the user exactly what was configured:

- Which channels are enabled
- Which recipients/channels each will send to
- Which events are toggled on
- Where the config was written

Then offer a test: "Want me to send a test notification now to verify it works? (y/n)"

If yes, invoke the `share/` subskill with event=`learn_proposals_ready` and a tiny dummy payload that clearly says "This is a test from codebase-rizz setup." Report the result.

If the test fails (MCP refuses, recipient invalid, channel not found), don't roll back the config — just tell the user what failed and how to fix it. They'll re-run setup or edit the config manually.

## Re-running

This subskill is idempotent by design. Running it again overwrites the `notifications` block with the new answers. Tell the user this up front if they re-run it on an already-configured repo:

> You already have notifications configured. Running setup again will replace your current settings. Continue? (y/n)

Show them the current config before asking.

## Instructions for missing MCPs

Don't inline install instructions here — they go in `../../references/mcp-install.md` so they can be maintained in one place. This subskill reads that file and relays the relevant section when a user needs to install something.
