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

| Agent | What it is | Install | Cost |
|-------|-----------|---------|------|
| **Gemini CLI** | Google's terminal agent | `npm i -g @google/gemini-cli` | **FREE** — personal Google account, ~1000 req/day, no card |
| **Antigravity** | Google agentic IDE (GUI) | vendor installer | **FREE** — Google account |
| **Claude Code** | Anthropic's terminal agent | `npm i -g @anthropic-ai/claude-code` | Anthropic API key / subscription |
| **Cursor** | AI IDE (GUI) | winget `Anysphere.Cursor` | Free tier (limited) / paid |
| **Codex CLI** | OpenAI terminal agent | `npm i -g @openai/codex` | OpenAI API / ChatGPT plan |
| **GitHub Copilot CLI** | Copilot in the terminal | `npm i -g @github/copilot` | Copilot plan |
| **Kiro** | AWS agentic IDE | vendor installer | varies |

The lab's `06-install-coding-agents.ps1` installs **both Gemini CLI (free) and
Claude Code**. For no-cost demos use **Gemini CLI** — every supported agent is
cloud-backed and needs *some* account, but Gemini's free tier needs only a Google
login (no payment). You can't point a supported agent at local Ollama to avoid this.

## Generate a session

On the box, after `bootstrap.ps1` has run (or run `06-install-coding-agents.ps1`
on its own). Use whichever agent you have credentials for.

**Free path — Gemini CLI (recommended for demos):**
```powershell
# 1. First run opens a browser to log in with a personal Google account (free)
gemini

# 2. Run a task that USES A TOOL. --yolo auto-approves the action (lab only).
gemini -p "create a file koi-test.txt with 'hello from the koi lab'" --yolo
gemini -p "run the shell command: whoami" --yolo
```

**Claude Code (needs Anthropic creds):**
```powershell
claude          # then /login, or:  $env:ANTHROPIC_API_KEY = "sk-ant-..."
claude -p "create a file koi-test.txt containing 'hello from the koi lab'" --dangerously-skip-permissions
```

Either fires the agent's PreToolUse/PostToolUse hooks → Koi captures the events →
a **session** appears in **Runtime Agent Activity** within a minute or two.

> `--yolo` / `--dangerously-skip-permissions` auto-approve the agent's actions so it
> doesn't pause for a prompt. Lab convenience only — never on a real workstation.

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
