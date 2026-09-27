# Lab

Tools for the test domain and test tenant only. **Never run these on a real company.**

---

## Build the lab

One VM is enough to show everything that touches Active Directory.

### 1. New-LabVM.ps1 (on your PC)

Creates the Hyper-V VM. You need a Windows Server ISO first. The [free 180-day evaluation](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025) works.

```powershell
.\Lab\New-LabVM.ps1 -IsoPath "C:\Users\me\Downloads\server2025.iso"

# or keep the whole lab on another drive
.\Lab\New-LabVM.ps1 -IsoPath "C:\Users\me\Downloads\server2025.iso" -Path "S:\Hyper-V"
```

It makes a Generation 2 VM (4 GB RAM that can grow, 2 CPUs, 60 GB disk) on the Default Switch, boots it from the ISO, and turns off checkpoints. Restoring a checkpoint on a domain controller causes more problems than it fixes.

`-Path` puts the VM's settings and its disk in one folder, so the whole lab is one folder to move, back up or delete.

Then install Windows in the VM window: **Desktop Experience**, Custom, whole disk.

### 2. Initialize-LabDomain.ps1 (inside the VM)

Run it twice: once to make it a domain controller, and once more after it reboots.

```powershell
.\Initialize-LabDomain.ps1 -DomainName lab.local
```

| Run | What happens |
|---|---|
| First | Installs AD DS, creates the domain, asks for a recovery password, reboots |
| Second | Creates the OUs and groups, and writes `Config\Clients\Lab\*.json` pointing at them |

It creates the setup the config examples expect:

```
OU=Identity
+-- OU=Users
|   +-- OU=Employees   <- new hires go here, one OU per department
|   \-- OU=Disabled    <- leavers get moved here
\-- OU=Groups          <- GRP-AllStaff and the GRP_ROLE_* groups
```

Both scripts are safe to run again. Anything that already exists is left alone.

### 3. Try it

```powershell
.\Onboarding\Onboarding.ps1 -Client Lab -FirstName Lisa -LastName Taylor -Title Accountant -Department Finance -Role Accountant
```

Dry run by default. Add `-Apply` to really create her.

The cloud steps (license, email lists, mailbox) are skipped until you add a Microsoft 365 tenant to the config. The free developer tenant now needs a paid Visual Studio subscription, so the easy option is the **Microsoft 365 Business Premium trial**: free for 30 days, up to 25 users, and it covers every cloud step. It needs a credit card and **starts charging after 30 days unless you cancel.**

---

## Reset-LabTenant.ps1

Deletes every member user that isn't in `exclude-users.txt`, so you can test onboarding again from scratch.

### Steps

1. Load the exclude list (stops if it's missing or empty)
2. In live mode, ask you to type `YES`
3. Check you're connected to Microsoft Graph
4. Get all member users from Entra
5. Stop if none of the accounts on the list are in this tenant (the list is for a different tenant, so your admin would be deleted too). The account you're signed in with is always kept
6. For each user not on the list:
   * Synced from AD: delete from AD, and Entra deletes it on the next sync
   * Cloud only: delete from Entra
7. Print how many were done, skipped, or failed

**New tenant?** Put its admin accounts in `exclude-users.txt` first.

### Usage

Dry run:
```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"
.\Lab\Reset-LabTenant.ps1
```
Live:
```powershell
.\Lab\Reset-LabTenant.ps1 -LiveRun
```
