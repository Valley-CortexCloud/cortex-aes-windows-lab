# Push-button deploy with GitHub Actions

The `terraform` workflow (`.github/workflows/terraform.yml`) deploys and destroys
the lab from the **Actions** tab — no local Terraform needed after setup.

- **Pull requests** → run `plan` only (safe preview).
- **Actions → terraform → Run workflow** → pick `plan`, `apply`, or `destroy`.

Auth is **AWS access keys stored as GitHub secrets**. Simple and fine for a
throwaway lab. The one habit that keeps it clean: use a **dedicated IAM user** for
this lab and **delete its access key when the POV wraps**.

---

## One-time setup (~5 minutes)

### 1. Create a lab IAM user + access key

In the AWS console (or CLI), create an IAM user, e.g. `koi-lab-ci`. For a lab,
attaching `PowerUserAccess` is the pragmatic choice (it can manage EC2/VPC/IAM
instance profiles but not account-wide IAM users). Tighter is better if you care;
see the minimal policy note at the bottom. Create an **access key** for it and
keep the two values handy.

### 2. Create the state bucket (once)

Terraform in CI needs remote state so it can track and later destroy what it built.
From any machine with AWS creds:

```bash
aws s3 mb s3://YOUR-UNIQUE-koi-lab-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket YOUR-UNIQUE-koi-lab-state \
  --versioning-configuration Status=Enabled
```

Bucket names are globally unique — pick something like `koi-lab-state-<yourinitials>-<rand>`.

### 3. Add the GitHub secrets + variables

Repo → **Settings → Secrets and variables → Actions**.

**Secrets** tab:

| Name | Value |
|------|-------|
| `AWS_ACCESS_KEY_ID` | the lab user's access key id |
| `AWS_SECRET_ACCESS_KEY` | the lab user's secret |

**Variables** tab:

| Name | Value / example |
|------|-----------------|
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | the bucket from step 2 |
| `ALLOWED_RDP_CIDR` | **your** public IP as a /32, e.g. `203.0.113.7/32` |

> `ALLOWED_RDP_CIDR` matters in CI: the local auto-detect would otherwise pick up
> GitHub's runner IP (wrong). Set it to the IP you'll RDP from. Find yours at
> https://checkip.amazonaws.com. If it changes, update the variable and re-run `apply`.

That's it. The workflow refuses to run with a clear error if any of these are missing.

---

## Deploy

1. **Actions** tab → **terraform** → **Run workflow**.
2. Choose `apply`. Watch it run.
3. The run **summary** prints the public IP, OS, and RDP source CIDR.

### Get the admin password (no terminal needed)

The password is sensitive, so it's never printed to the Actions log. Instead:

1. **Actions → terraform → Run workflow → `credentials`.** (An `apply` run also
   produces this automatically.)
2. When the run finishes, open it and download the **`rdp-connection`** artifact
   from the *Artifacts* section at the bottom of the run page.
3. It's a `connection.txt` with the host, user, and password.

The artifact is private to repo collaborators and auto-expires in 1 day. Re-run
`credentials` any time to regenerate it.

> Prefer a terminal? The password also comes from `terraform output -raw admin_password`
> once you've `init`'d against the remote state (bucket/key/region as in step 2 of setup).

Then RDP to the public IP as `Administrator`.

## Destroy

**Actions → terraform → Run workflow → `destroy`.** Tears everything down and
(for Windows 11) releases the Dedicated Host so it stops billing.

---

## Local vs CI — they coexist

- **Local:** `backend.tf.ci` is ignored (not a `.tf` file), so `terraform init`
  uses local state and needs no bucket. Great for quick iteration.
- **CI:** the workflow copies `backend.tf.ci` → `backend.tf` and inits against S3.

Don't mix the two for the *same* instance — pick where state lives per deployment,
or you'll have two state files that each think they own resources.

---

## Minimal IAM (optional, if PowerUserAccess is too broad)

The lab creates: EC2 instance + key pair + security group, an IAM role + instance
profile (for SSM), and reads SSM public parameters. A tighter policy needs
`ec2:*` (scoped to the region), `iam:*Role*` / `iam:*InstanceProfile*` /
`iam:PassRole`, `ssm:GetParameters`, plus `s3:*Object` + `s3:ListBucket` on the
state bucket. `PowerUserAccess` covers all of this except the IAM role creation —
for that add `IAMFullAccess` or a scoped inline policy. For a short lab,
`PowerUserAccess` + `IAMFullAccess` on a user you delete afterward is the usual call.
