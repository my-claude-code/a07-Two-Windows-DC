# a07 — Two Windows Domain Controllers

## What this is

Two independent Windows Server 2022 domain controllers deployed in Azure via Terraform — DC1 hosts `firstad.local` in Canada East, DC2 hosts `secondad.local` in West US 2. Each DC gets its own VNet, NSG (all-open), and public IP for RDP. Both domains are completely separate (no trust relationship). This is a testing environment, so the password policy is relaxed to allow a one-character password after setup completes.

## How it works

Terraform provisions each VM and then uses the Custom Script Extension to run a PowerShell script that:

1. Installs the `AD-Domain-Services` Windows feature
2. Writes a post-reboot configuration script (`C:\PostADSetup.ps1`) that will disable password complexity, set minimum password length to 0, and change the `ivansto` domain admin password to `"1"`
3. Registers that script as a SYSTEM scheduled task that fires at next startup
4. Runs `Install-ADDSForest` to promote the VM to a domain controller (no immediate reboot)
5. Issues a delayed shutdown (`/t 120`) so CSE has 120 seconds to record success, then the VM reboots

After the reboot, the scheduled task runs as SYSTEM, waits for AD services to be ready, relaxes the domain password policy, changes the password to `"1"`, and removes itself.

---

## Architecture

```
Internet (RDP port 3389)
      │
      ├──▶ Public IP — DC1 (Canada East)
      │         │
      │     NSG (all open)
      │         │
      │     VNet 10.0.0.0/16 — subnet 10.0.1.0/24
      │         │
      │     vm-dc1 (Windows Server 2022)
      │     Domain: firstad.local
      │     Admin: ivansto
      │
      └──▶ Public IP — DC2 (West US 2)
                │
            NSG (all open)
                │
            VNet 10.1.0.0/16 — subnet 10.1.1.0/24
                │
            vm-dc2 (Windows Server 2022)
            Domain: secondad.local
            Admin: ivansto
```

---

## Deployment

### Prerequisites
- Azure CLI logged in (`az login`)
- Terraform installed

### Steps

```bash
git clone https://github.com/my-claude-code/a07-Two-Windows-DC.git
cd a07-Two-Windows-DC

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and add your subscription ID
```

`terraform.tfvars`:
```hcl
subscription_id = "your-azure-subscription-id"
```

```bash
terraform init
terraform apply
```

Deployment takes roughly **15–20 minutes** — VM provisioning (~5 min) plus the AD DS installation and promotion (~10 min) that happens via Custom Script Extension.

---

## After Deployment

Once `terraform apply` completes:

1. Get the public IPs from the Terraform output
2. RDP to each VM:
   - Username: `ivansto`
   - Password: `ClaudeCode2023!` (initial)
3. **Wait ~5 minutes after RDP is available** for the post-reboot scheduled task to finish changing the password policy and setting the password to `"1"`
4. After the scheduled task completes, you can log in with password `1`

If you're not sure whether the task has run, check `C:\post-setup.log` on the VM.

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `subscription_id` | — | Azure subscription ID (**required in tfvars**) |
| `admin_username` | `ivansto` | VM and domain administrator username |
| `admin_password` | `ClaudeCode2023!` | Initial password (Azure complexity required at VM creation) |
| `vm_size` | `Standard_B2s_v2` | VM size for both DCs |

---

## Outputs

| Output | Description |
|---|---|
| `dc1_public_ip` | Public IP for RDP to DC1 (firstad.local) |
| `dc2_public_ip` | Public IP for RDP to DC2 (secondad.local) |

---

## Estimated Cost

| Resource | Est. $/month |
|---|---|
| 2× Standard_B2s_v2 VMs | ~$30 |
| 2× Standard public IPs | ~$7 |
| 2× managed OS disks (Standard_LRS) | ~$4 |
| **Total** | **~$40** |

### Teardown

```bash
terraform destroy
```

---

## Logs

Both scripts write logs to the VM for debugging:

| File | Contents |
|---|---|
| `C:\dc-setup.log` | Main CSE script output (feature install + domain promotion) |
| `C:\PostADSetup.ps1` | The post-reboot script that was written to disk |
| `C:\post-setup.log` | Post-reboot script output (password policy + password change) |

---

## Project Series

| Project | Description |
|---|---|
| a01 | Flask + SQLite, local |
| a02 | Flask + MySQL, local |
| a03 | Terraform: 2 Azure VMs (MySQL + App), West Europe |
| a04 | Terraform: App Gateway + Web VMSS + Internal NLB + App VMSS + MySQL VM |
| a05 | Terraform: Same as a04 with MySQL Flexible Server, Canada East |
| a06 | Terraform: Two-region active-active, Front Door, MySQL primary/standby |
| **a07** | **Terraform: Two independent Windows AD domains (firstad.local, secondad.local)** |
