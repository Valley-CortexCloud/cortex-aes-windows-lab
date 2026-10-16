output "instance_id" {
  description = "EC2 instance id of the lab box."
  value       = aws_instance.lab.id
}

output "public_ip" {
  description = "Public IP for RDP."
  value       = aws_instance.lab.public_ip
}

output "os_edition" {
  description = "Which Windows edition was launched."
  value       = var.os_edition
}

output "rdp_source_cidr" {
  description = "The source CIDR that is allowed to RDP in."
  value       = local.detected_ip
}

output "admin_username" {
  description = "Local administrator username for RDP."
  value       = "Administrator"
}

output "admin_password" {
  description = "Decrypted Windows administrator password. Marked sensitive; run: terraform output -raw admin_password"
  value       = rsadecrypt(aws_instance.lab.password_data, tls_private_key.lab.private_key_pem)
  sensitive   = true
}

output "private_key_path" {
  description = "Local path to the generated private key (also usable to re-decrypt the password manually)."
  value       = local_sensitive_file.private_key.filename
}

output "rdp_hint" {
  description = "How to connect."
  value       = <<-EOT

    1. Get the password:   terraform output -raw admin_password
    2. RDP to:             ${aws_instance.lab.public_ip}:3389
       user:               Administrator
    3. First login can take a few minutes while Windows finishes OOBE.
    4. If auto_provision=true, base prep (Chocolatey, git) runs at boot. Check
       C:\\koi-lab-bootstrap.log on the box. Then run the per-user light-up
       payload in provisioning\\ as the logged-in user (see repo README).
  EOT
}

output "next_steps" {
  description = "Pointer to the runbook."
  value       = "See the top-level README.md (section 'Run the lab') and use-cases/test-plan.md."
}
