# MCP server install instructions

This file holds install guidance for every MCP server `share/setup/` knows how to use. When the user picks a channel and the corresponding MCP isn't installed, setup relays the relevant section from this file.

Keep instructions concrete but OS-agnostic where possible. macOS is the current primary target. Link to upstream docs for the definitive source of truth — MCP server setup changes often and we should not be the source.

## Gmail

Gmail works as a lightweight MCP integration that ships with Claude Code. There's no separate plugin to install — it's a thin MCP server wired through the user's Google account.

### Setup steps

1. **Authenticate.** In any Claude Code session, invoke a Gmail tool (for example, `mcp__claude_ai_Gmail__authenticate` if it's exposed, or just ask Claude to "send a test email via Gmail"). The first call opens a browser window for Google OAuth — grant access to the Google account you want emails to send from
2. **Verify the tools are available.** After auth, tools under the `mcp__` namespace whose names include `gmail` should be in Claude Code's tool list. Common ones:
   - `mcp__claude_ai_Gmail__authenticate`
   - a send-message tool (exact name depends on the MCP version)
3. **Re-run `share/setup/`** — it should now detect a Gmail MCP and let you configure recipients

### Sender identity

Emails send **from whatever Google account you authenticated with**. Recipients see that address as the sender, just like if you'd typed the email yourself. There is no "Claude bot" Gmail account.

### If Gmail MCP tools are not visible

- Restart Claude Code so the tool list refreshes
- Check the MCP docs: https://code.claude.com/docs/en/mcp.md
- If the integration isn't working at all, `share/setup/` will fall back to the markdown file option and you can use that while troubleshooting

## Slack

Slack uses the **official Claude plugin** from the `claude-plugins-official` marketplace. This is the supported path — don't try to build a custom bot or use community MCP servers unless you have a specific reason.

### Setup steps

**1. Install the Claude app in your Slack workspace (one-time, workspace admin)**

Have a workspace admin install the official Claude app from the Slack Marketplace:

https://slack.com/marketplace/A08SF47R6P4

**2. Connect your Slack account to your Claude account**

In Slack, open the **Claude** app → go to the **App Home** tab → click **"Connect"**. This links your Slack identity to your Claude account so Claude Code can post on your workspace's behalf.

**3. Install the Slack plugin in Claude Code**

Inside any Claude Code session, run the slash command:

```
/plugin install slack@claude-plugins-official
```

This adds Slack MCP tools to your Claude Code session. Restart Claude Code afterwards so the tools show up.

**4. Verify the tools are available**

After restart, Slack-related tools should appear in the tool list (look for names containing `slack`). If they don't, check the plugin status with `/plugin` and re-install if needed.

**5. Re-run `share/setup/`**

The setup subskill will detect the Slack MCP and let you configure which channels codebase-rizz posts to.

### Sender identity

Messages post **as the Claude Slack app**, using the connection you set up in step 2. Recipients see the message as coming from "Claude" in Slack, not from you personally and not from a custom bot. This is intentional — it keeps the sender clearly identifiable as automated across every team using codebase-rizz.

### Permissions per channel

The Claude app needs to be a member of any channel it posts to. For each target channel in Slack:

```
/invite @Claude
```

(or add via channel settings → Integrations). You only need to do this once per channel.

### References

- Claude Code in Slack: https://code.claude.com/docs/en/slack.md
- Plugin discovery and install: https://code.claude.com/docs/en/discover-plugins.md
- Slack marketplace listing: https://slack.com/marketplace/A08SF47R6P4

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
