# Runtime Agent Activity (AIDR) — generating and testing sessions

AIDR is Koi's session-centric view of what AI **coding agents** actually did:
every shell command, file access, and MCP tool call, correlated into the coding
session that produced it, with enforcement policies applied inline.

## The #1 gotcha: Claude Desktop ≠ Claude Code

**Claude Desktop (the chat app) generates NO AIDR activity.** It is not a coding
agent — it has no tool-execution hooks on your machine. Chatting in it is invisible
to Koi by design.

AIDR only populates from **supported coding agents**, captured via each agent's
native hooks:

| Agent | What it is | Install |
|-------|-----------|---------|
| **Claude Code** | Anthropic's terminal coding agent | `npm i -g @anthropic-ai/claude-code` |
| **Cursor** | AI IDE (GUI) | winget `Anysphere.Cursor` |
| **Codex CLI** | OpenAI terminal agent | `npm i -g @openai/codex` |
| **GitHub Copilot CLI** | Copilot in the terminal | `npm i -g @github/copilot` |
| **Kiro** | AWS agentic IDE | vendor installer |
| **Antigravity** | Google agentic IDE | vendor installer |

The lab installs **Claude Code CLI** (`provisioning/06-install-coding-agents.ps1`)
because Koi already deploys its enforcement hooks. Any of the others work too.

## Generate a session (Claude Code)

On the box, after `bootstrap.ps1` has run (or run `06-install-coding-agents.ps1`
on its own):

```powershell
# 1. Authenticate once (needs an Anthropic API key or a Claude subscription)
claude          # then /login, or:  $env:ANTHROPIC_API_KEY = "sk-ant-..."

# 2. Run a task that USES A TOOL (file write, shell command, MCP call)
claude -p "create a file koi-test.txt containing 'hello from the koi lab'" --dangerously-skip-permissions
claude -p "run the shell command: whoami" --dangerously-skip-permissions
```

Each of those fires Claude Code's PreToolUse/PostToolUse hooks → Koi captures the
events → a **session** appears in **Runtime Agent Activity** within a minute or two.

> `--dangerously-skip-permissions` is a lab convenience so the agent doesn't pause
> for approval. Never use it on a real workstation.

## What to look for in the AIDR console

Open the session and verify:

- **Session timeline** — the file write / shell command / MCP tool call you triggered,
  each with its target (path, command, or tool name).
- **Agent extensions** — which MCP servers / skills the session used (ties back to
  the MCP configs from step 04).
- **Governed by** — which enforcement policy fired. Koi pre-deployed hooks to
  `C:\Program Files\ClaudeCode\managed-settings.d\koi-security.json`, so the session
  should show as governed.
- **Blocked actions** — if you set a policy to block (e.g. a specific command), run a
  task that triggers it and confirm it's stopped and marked in the timeline.
- **Models used** / **Identity** — model attribution and the user the session ran as.
- **Prompt redaction** — prompts show as `[PROMPT REDACTED]` by default. An admin can
  turn redaction off under Settings → Advanced Settings → AI Agents Runtime Visibility
  (forward-only; past prompts are never recoverable).

## Enforcement test (the real differentiator)

1. In Koi, set a runtime policy to **block** a command pattern (e.g. anything touching
   `curl` or a secrets path).
2. `claude -p "run the shell command: curl https://example.com" --dangerously-skip-permissions`
3. Confirm the action is **blocked** in the session timeline, with the policy named
   under *Governed by*. That's agentic runtime control working end to end.
