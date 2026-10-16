# Windows 11 on EC2 — why it's not the default, and how to switch

You asked for a Windows 11 target. Here's the honest tradeoff and how to flip it on.

## The catch

There is **no AWS-provided, shared-tenancy Windows 11 AMI**. Windows 11 is a *client*
OS, and Microsoft licensing requires client Windows on EC2 to run on a **Dedicated Host**
with **BYOL** (bring-your-own-license) media. That means:

- You import your own Windows 11 image into the account/region (EC2 VM Import, or an
  approved Marketplace Win11 AMI), and
- You pay for a **Dedicated Host**, which is materially more expensive than a shared
  `t3.large`, and
- Setup is fiddlier (host allocation, AZ pinning, license attestation).

## Why the default is Windows Server 2022

For **Koi / Cortex AES discovery**, Server 2022 and Windows 11 are effectively identical:

- Same user-profile paths (`C:\Users\<u>\.vscode`, `%APPDATA%\Claude`, `%LOCALAPPDATA%\...\Extensions`)
- Same browser/IDE/MCP/AI-tool enumeration
- Same PowerShell wrapper + WinPython execution model
- Same registry remediation paths

So the default gets you a working lab on `terraform apply` with identical product
behaviour, at a fraction of the cost. Use Win11 only when you need a pixel-accurate
*desktop* for a demo screenshare.

## How to switch to Windows 11

1. Get a Windows 11 AMI id in your region (import your own, or an approved Marketplace one).
2. In `terraform.tfvars`:
   ```hcl
   os_edition       = "windows11"
   windows11_ami_id = "ami-xxxxxxxxxxxxxxxxx"
   instance_type    = "m5.large"   # pick a family your dedicated host supports
   ```
3. `terraform apply`. The config allocates an `aws_ec2_host` (Dedicated Host) in the
   target subnet's AZ and launches the instance with `tenancy = "host"`.
4. **Remember to release the host** on teardown (`terraform destroy` handles it, but
   Dedicated Hosts bill while allocated — don't leave it running).

## Alternative worth knowing

If the point is "a real Windows 11 desktop" rather than EC2 specifically, **Amazon
WorkSpaces** gives you a managed Win11 desktop without Dedicated Host mechanics. It's a
different IaC surface (not in this repo), but it's often the cheaper/cleaner way to get a
genuine Win11 endpoint for a demo. Say the word and I'll add a WorkSpaces variant.
