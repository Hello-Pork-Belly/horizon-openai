# Security Host Inventory Example Notes

## Host Security File (`inventory/hosts/host-security-a.yml`)
This sample provides non-sensitive planning inputs for security-host dry-run flows.

### Base Required Keys
- `id`
- `role`
- `os`
- `arch`
- `resources`
- `tailscale.ip`
- `ssh.user`
- `ssh.port`

### Security Planning Keys
- `security_profile.bruteforce_guard`
- `security_profile.scan_schedule`
- `security_profile.mail_alerts`
- `security_profile.log_retention_days`

## Usage
- Optional dry-run input override:
  - `HOST_FILE=inventory/hosts/host-security-a.yml`
