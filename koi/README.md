# Deploying Koi / Cortex AES on the lab box

Three ways to run the Koi script package on Windows. For a POV where the goal is
to *understand* the product, run them in this order.

> You supply the artifacts. `Koi.msi` and `mdm.ps1` come from your AES deployment
> portal (**Settings → Deployment**) with your `customer_id` / `customer_slug`.
> Put them in [`artifacts/`](./artifacts) (gitignored).

## What actually runs

The payload is a **Python script package** wrapped in a **PowerShell wrapper** on
Windows. The wrapper handles UAC/admin, downloads a signed **WinPython** portable
runtime, and runs the Python. Each run:

1. **Discovery** — enumerates every local user profile for IDE/browser extensions,
   MCP server configs, and AI tools, with versions.
2. **Risk scoring** — the AES engine scores what it found (reputation, exploitability,
   intent, privilege).
3. **Remediation** (only when you’ve set policy) — deletes prohibited extension files,
   cleans registry, and deploys block policies to stop reinstalls.

Network-config deployment (PAC file + hosts-file grouping) is **off by default** and
only runs if you explicitly enable it.

## The three methods

| | **1. Agentless (manual / scheduled)** | **2. Installed (Windows Service)** | **3. AES agent (persistent)** |
|---|---|---|---|
| What it is | Run `mdm.ps1` yourself or via a scheduler | `KoiService` installed from `Koi.msi`, self-schedules | Persistent Cortex binary, self-schedules, content-managed |
| Scheduler | You / MDM / a scheduled task | The service (default hourly) | The agent (default hourly) |
| Install effort | None (just run it) | One `msiexec` | One-time deploy |
| Updates | Manual re-download **or** auto wrapper | Follows script-package mode (managed/manual) | Fully managed by Palo Alto content releases |
| Visibility while learning | **Highest** — you see each run | Medium — check `KoiService.log` | Lowest — it just works |
| Best for | Understanding behaviour | Prod-like single-box without MDM | Real fleet / ADP production |
| Lab script | `01-run-script-manual.ps1`, `03-scheduled-task.ps1` | `02-install-service.ps1` | n/a in this lab (needs Cortex content infra) |

**Recommended lab path:** `01` (watch one manual run) → `03` (prove the scheduled
cadence) → `02` (production-like service). Save method 3 for the ADP production design
conversation — it leans on the broader Cortex content pipeline rather than a single VM.

## Prerequisites (Windows)

- **Administrator** — the wrapper manages UAC and needs admin to discover all
  profiles and to remediate. (Full Disk Access / PPPC is a *macOS* concept; on
  Windows it’s just admin + UAC.)
- **Outbound HTTPS** — first run pulls the signed WinPython runtime (and, in managed
  update mode, the latest signed script). The lab’s security group already allows egress.

## Run it

```powershell
# Method 1 - manual single run (max visibility)
./01-run-script-manual.ps1 -CustomerId "<id>" -CustomerSlug "<slug>"

# Method 1b - scheduled cadence (simulate an MDM), every 15 min for fast feedback
./03-scheduled-task.ps1 -IntervalMinutes 15

# Method 2 - install the Windows Service (prod-like). INTERVAL in MINUTES, 5 = fast lab loop
./02-install-service.ps1 -CustomerId "<id>" -CustomerSlug "<slug>" -IntervalMinutes 5
```

## Updating (managed vs manual)

- **Managed/Automatic** — a lightweight wrapper fetches the latest signed script
  automatically; zero maintenance.
- **Manual** — re-download `mdm.ps1` from the portal and drop it in
  `C:\ProgramData\Koi\` (for the service) or `artifacts\` (for manual runs).

Re-running the MSI (`msiexec /i Koi.msi /qn`) updates the service in place.

## Debugging

- `C:\ProgramData\Koi\` exists and contains `KoiService.exe` + `mdm.ps1`.
- `sc.exe query KoiService` shows the service (or open `services.msc`).
- `C:\ProgramData\Koi\KoiService.log` appears once the service runs.
- Verbose MSI log: add `/l*v install.log` (method 2 script does this automatically).
- Manual runs write a full transcript next to the script (method 1).

## Tear down

```powershell
./uninstall.ps1              # remove service + scheduled task
./uninstall.ps1 -Rollback    # roll back deployed config first, then remove
```
