# MCP server install instructions

This file holds install guidance for every MCP server `share/setup/` knows how to use. When the user picks a channel and the corresponding MCP isn't installed, setup relays the relevant section from this file.

Keep instructions concrete but OS-agnostic where possible. macOS is the current primary target. Link to upstream docs for the definitive source of truth — MCP server setup changes often and we should not be the source.

## Gmail

The easiest path is the MCP Anthropic provides for claude.ai and Claude Code users.

### Option A: Anthropic's hosted Gmail MCP

If you use claude.ai, you may already have it authenticated. To enable it in Claude Code:

1. Open your Claude Code settings (`~/.claude/settings.json` or via the settings UI)
2. Add the Gmail MCP server to your `mcpServers` configuration. Refer to the official Claude Code MCP docs for the latest config format: https://docs.claude.com/en/docs/claude-code/mcp
3. Restart Claude Code so the tool list refreshes
4. Re-run `share/setup/` — the skill should now detect the MCP

Gmail MCP sends emails from the authenticated account. The user will be prompted on first use to log in with OAuth.

### Option B: Community Gmail MCP servers

Several community-maintained Gmail MCPs exist on GitHub. They typically need:
- A Google Cloud project with the Gmail API enabled
- OAuth client credentials
- First-run authentication

These are more work to set up but give you full control. Only use if the hosted option doesn't work for you.

## Slack

Slack MCPs require a one-time Slack app creation by a workspace admin before they can post to any channel.

### Create the Slack app

1. Go to https://api.slack.com/apps and click **Create New App → From scratch**
2. Name it (e.g. "codebase-rizz"), pick your workspace
3. Under **OAuth & Permissions**, add these bot token scopes:
   - `chat:write` (post messages)
   - `chat:write.public` (post to channels without being invited) — optional, add if you want less friction
4. Install the app to your workspace (admin approval may be required)
5. Copy the **Bot User OAuth Token** (starts with `xoxb-`)

### Install the Slack MCP

Find a Slack MCP server (community-maintained; check https://github.com/modelcontextprotocol for current options) and:

1. Install it per its README
2. Provide the bot token when prompted or via config
3. Add the server to your Claude Code `mcpServers` config
4. Restart Claude Code

### Invite the bot to your target channels

The app only posts to channels it's been invited to (unless `chat:write.public` is granted). In Slack, for each channel you want to use:

```
/invite @codebase-rizz
```

Re-run `share/setup/` after the MCP is installed and the bot is in the channels you want.

## Troubleshooting

**"No Gmail/Slack tools detected after install"**
- Restart Claude Code. MCP tool lists are loaded at session start.
- Verify the MCP server is actually running. For stdio-based MCPs, check that the command in your config is correct and exits cleanly with `--help`
- Check `~/.claude/logs/` for MCP startup errors

**"MCP is detected but send fails with 'not authenticated'"**
- For Gmail: run any tool that calls `gmail_authenticate` to kick off OAuth
- For Slack: double-check the bot token is correct and hasn't been revoked
- Some MCPs cache auth tokens — clearing the cache and re-authenticating can fix stuck states

**"Send succeeds but nothing arrives"**
- Gmail: check the sender's Sent folder first — the email probably sent, the recipient just isn't receiving. Check spam folders on the receiving side
- Slack: verify the bot is a member of the target channel. `chat:write.public` bypasses this but isn't always granted
