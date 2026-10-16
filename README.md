# Cortex AES (Koi) — Windows POV Lab

A reproducible lab for learning **Palo Alto Cortex AES** (Agentic Endpoint Security,
formerly **Koi**) and dry-running a deployment before standing it up for a customer.

It does three things:

1. **Stands up a Windows VM in AWS** (Terraform).
2. **Lights it up** with the agentic artifacts AES is built to find — IDE + browser
   extensions, MCP servers, and local AI tools (VS Code, Cursor, Windsurf, Claude
   Desktop, Ollama) — and records a **ground-truth inventory**.
3. **Deploys the Koi script package** three ways (manual, scheduled, Windows Service)
   and gives you a **POV test plan** to validate discovery, risk scoring, and remediation.

> **What this repo does not contain:** the Koi `Koi.msi` / `mdm.ps1` artifacts or any
> customer IDs — those come from your AES deployment portal and are gitignored. And it
> does not vendor Palo Alto's internal docs; keep those in your own notes.

---

## Architecture

```
            your workstation
                  │  terraform apply          RDP (3389, your IP only)
                  ▼                                   │
      ┌───────────────────────────── AWS ────────────┼───────────────┐
      │  default VPC / public subnet                  ▼               │
      │   ┌──────────────────────────────────────────────────────┐   │
      │   │  EC2 Windows (Server 2022 default | Win11 opt-in)      │   │
      │   │                                                        │   │
      │   │   provisioning/  ──► VS Code, Cursor, Windsurf,        │   │
      │   │                      Claude Desktop, Ollama,           │   │
      │   │                      IDE + browser extensions,         │   │
      │   │                      MCP server configs                │   │
      │   │                         │                              │   │
      │   │   koi/  ──► Koi script package (manual/scheduled/svc)  │   │
      │   │                         │ discovery + risk + remediate │   │
      │   └─────────────────────────┼──────────────────────────────┘   │
      │        IAM role (SSM)        │ reports in                      │
      └──────────────────────────────┼─────────────────────────────────┘
                                      ▼
                           Cortex AES console (SaaS)
```

## Repo layout

```
terraform/      AWS Windows VM, SG (RDP from your IP), SSM, password output
provisioning/   PowerShell "light-up" payload + ground-truth inventory generator
koi/            Deploy scripts for all 3 methods + uninstall; artifacts/ is where
                YOU drop Koi.msi / mdm.ps1 (gitignored)
use-cases/      POV test matrix + scorecard
docs/           Windows 11 notes
```

## Prerequisites

- An AWS account + credentials (`aws configure` or env vars). The lab uses the
  **default VPC** and creates a key pair, SG, IAM role, and one EC2 instance.
- **Terraform ≥ 1.5** locally. *(Heads-up: `terraform validate` was not run in the
  authoring sandbox because `releases.hashicorp.com` was blocked — run
  `terraform init && terraform validate` once on your side before `apply`.)*
- An RDP client.
- Your **Cortex AES portal access** to download `Koi.msi` / `mdm.ps1` and your
  `customer_id` / `customer_slug`.

---

## Run the lab

### 1. Provision the VM

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit region/owner; leave os_edition=server2022 to start
terraform init
terraform validate      # recommended (see note above)
terraform apply
```

Default is **Windows Server 2022** (works immediately; identical AES discovery
behaviour). To use a real **Windows 11** desktop, see
[`docs/WINDOWS11_NOTES.md`](docs/WINDOWS11_NOTES.md) — it needs a Dedicated Host + BYOL AMI.

RDP in:

```bash
terraform output -raw admin_password     # the decrypted Administrator password
terraform output public_ip               # RDP here as 'Administrator'
```

The security group opens 3389 **only to your IP** (auto-detected, or pin it with
`allowed_rdp_cidr`).

### 2. Light it up (run over RDP, as the logged-in user, elevated)

Copy the `provisioning/` folder to the box (or `git clone` this repo there), then:

```powershell
cd provisioning
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
# launch Chrome and Edge once so force-installed extensions land, then:
powershell -ExecutionPolicy Bypass -File .\05-inventory.ps1
```

> Run this **as the interactive user**, not via `user_data`. Koi discovers *per-user*
> profiles, and `user_data` runs as SYSTEM — artifacts would land in the wrong profile.

You now have `provisioning/expected-inventory.json` — your discovery scorecard.

### 3. Deploy Koi

Drop `Koi.msi` / `mdm.ps1` into `koi/artifacts/`, then follow
[`koi/README.md`](koi/README.md). Recommended learning order:

```powershell
cd koi
./01-run-script-manual.ps1 -CustomerId "<id>" -CustomerSlug "<slug>"   # watch one run
./03-scheduled-task.ps1 -IntervalMinutes 15                            # simulate MDM cadence
./02-install-service.ps1 -CustomerId "<id>" -CustomerSlug "<slug>" -IntervalMinutes 5  # prod-like
```

### 4. Validate

Work through [`use-cases/test-plan.md`](use-cases/test-plan.md): compare the AES console
against `expected-inventory.json`, then exercise risk scoring and remediation.

### 5. Tear down

```powershell
# on the box, if you installed Koi:
cd koi; ./uninstall.ps1 -Rollback
```
```bash
# from terraform/ :
terraform destroy
```

---

## Cost & safety notes

- Server 2022 `t3.large` + 100 GB gp3 is a few dollars a day — **`terraform destroy`
  when idle.** A **Windows 11 Dedicated Host bills while allocated**, so don't leave it up.
- RDP is restricted to a single source IP; the root volume is encrypted; IMDSv2 is
  enforced. Still a lab — don't put real data on it.
- The MCP `github` config ships with a placeholder token (`REPLACE_ME_lab_token`), not
  a real credential.
- Koi's network-config/grouping (PAC + hosts file) is **off by default**; only enable it
  deliberately (test case 10).

## Taking this to ADP (production)

For the customer deployment, the differences from this lab:

- **Method 3 (persistent AES agent)** is the production recommendation — content-managed
  updates from Palo Alto, hands-off cadence. This lab stops at the service/script methods
  because the agent leans on the broader Cortex content pipeline.
- Deployment goes through ADP's **MDM/EDR** (Intune/CrowdStrike/etc.), not manual runs —
  the agentless script and the MSI both drop straight into those tools.
- Roll out to a **pilot scope first**, validate coverage in **Covered endpoints**, then
  widen scope — same discovery/validation loop as this lab, just at fleet scale.
