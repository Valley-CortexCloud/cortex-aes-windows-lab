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
| **Antigravity** | Google agentic IDE (GUI) | https://antigravity.google | **FREE** — Google account sign-in (the only free path that reports to Koi) |
| **Gemini CLI** | Google's terminal agent | `npm i -g @google/gemini-cli` | API key loads hooks but Koi records nothing; free Google login deprecated — ❌ for Koi |
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

### ⚠️ CRITICAL: an API key silently disables Koi's hooks

This is the single biggest trap in AIDR testing, and it's documented behavior:

> **A Gemini-family session running on a `GEMINI_API_KEY` loads Koi's hooks but
> never dispatches them.** Koi records NOTHING, with no error. Hook dispatch
> requires a **Google account sign-in**. (Antigravity's hidden `modeProvider`
> setting forces this same API-key mode.)

Combined with Google deprecating the free "Sign in with Google" for the standalone
**Gemini CLI**, the practical result is:

- **Gemini CLI + API key** → runs, but reports nothing to Koi. ❌
- **Gemini CLI + Google login** → login path deprecated. ❌
- **Antigravity + Google account sign-in** → hooks fire, Koi records. ✅ **(the free path)**

**Free path — Antigravity with a Google account:**
```powershell
# Make sure no API key / modeProvider is forcing API-key mode:
Remove-Item Env:GEMINI_API_KEY -ErrorAction SilentlyContinue
[Environment]::SetEnvironmentVariable("GEMINI_API_KEY", $null, "User")
[Environment]::SetEnvironmentVariable("GEMINI_API_KEY", $null, "Machine")
Get-ChildItem "$env:USERPROFILE","$env:APPDATA","$env:LOCALAPPDATA" -Recurse -Filter settings.json -ErrorAction SilentlyContinue |
  Select-String -Pattern "modeProvider" -List | Select-Object Path   # remove if found
```
1. Install Antigravity from https://antigravity.google
2. **Sign in with a Google account** (free — no card).
3. Ask it to read or edit a file. Removing the API-key setting restores hook
   dispatch immediately (no restart). A session appears in Koi within ~1-2 min.

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

## Silent hook-disablers (critical for ADP rollout)

Koi's files can be correctly deployed and still fire nothing because an agent
setting silently suppresses hook dispatch. No error is raised. Audit these before
concluding coverage is complete:

- **Antigravity / Gemini** — an API-key session (`GEMINI_API_KEY` + hidden
  `modeProvider`) loads hooks but never dispatches. Use Google account sign-in.
- **Claude Code** — **server-managed settings** (set in the claude.ai admin console)
  *override* file-based settings entirely, and Koi's hooks never load. The two
  delivery methods do not merge. Govern Claude Code via **file-based** managed
  settings or OS-level MDM; do **not** configure it in the claude.ai admin console
  on machines Koi should govern.
- **Claude Code hook kill-switches** — `disableAllHooks` must be unset/false, and
  `allowManagedHooksOnly` must be unset, or Koi's hooks stop firing.
- **GitHub Copilot CLI** — requires one app restart after hook deployment before
  hooks take effect.

These are strong POV talking points: "the control can be present on disk and still
be silently off" is exactly the assurance gap ADP needs Koi (and this validation)
to close.

## Enforcement test (the real differentiator)

1. In Koi, set a runtime policy to **block** a command pattern (e.g. anything touching
   `curl` or a secrets path).
2. `claude -p "run the shell command: curl https://example.com" --dangerously-skip-permissions`
3. Confirm the action is **blocked** in the session timeline, with the policy named
   under *Governed by*. That's agentic runtime control working end to end.
