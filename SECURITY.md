# Security

How these scripts handle passwords, secrets and access. Short version: **no passwords anywhere, nothing secret in the repo, and each script only gets the access it needs.**

---

## What is secret, and where it's kept

| Thing | Secret? | Where it's kept | Who can read it |
|---|---|---|---|
| App sign-in (Graph, Exchange, SharePoint) | **Yes**, the certificate's private key | Windows certificate store on the automation server, **can't be exported** | The service account (gMSA) and local admins |
| Certificate thumbprint | No, it's just an ID | Client config | - |
| Tenant ID, client (app) ID | No, they're just IDs | Client config | - |
| Teams webhook URL | **Yes**, anyone with it can post | Vault (SecretManagement) | The service account |
| Any other API key | **Yes** | Vault | The service account |
| Service account password | - | **There isn't one.** It's a gMSA, so Windows changes the password by itself | - |
| New hire temp passwords and access passes | **Yes** | Only in memory. Shown once on screen or emailed to IT | Never logged, never in reports or the SharePoint list |
| Client configs | No secrets inside | `Config/Clients/` (gitignored) or `SCRIPTS_CONFIG_ROOT` | - |

---

## How it works

**1. Certificates, not client secrets**
The Entra app registration only has a certificate, never a client secret.
[`Setup/New-AutomationCertificate.ps1`](Setup/New-AutomationCertificate.ps1) creates the key on the server, makes it so it can't be exported,
and lets only the service account read it. Only the public key gets uploaded to Entra.

**2. Configs point to the vault**
A config never holds a secret. It holds the secret's name instead:

```json
"AlertWebhookUrl": "secret:ClientA-TeamsWebhook"
```

When the script runs, `Get-Config` gets the real value from the vault (`Microsoft.PowerShell.SecretManagement`):

- **Lab:** SecretStore (encrypted, tied to the service account's profile). [`Setup/Set-AutomationSecret.ps1`](Setup/Set-AutomationSecret.ps1) saves values without them ever being typed on the command line.
- **Production:** Azure Key Vault, registered under the same vault name. No code changes needed.

**3. Secrets never end up in the logs**
`Get-Config` remembers every secret it loads, and `Write-Log` swaps it for `***` in every line. That includes error messages that print a URL.

**4. Scanning**
CI runs [gitleaks](https://github.com/gitleaks/gitleaks) on every push and pull request, across the whole history.
Also turn on GitHub **secret scanning and push protection** in the repo settings, as a backup.

---

## Least privilege

Each client config has its own `ClientId`, so **each script can have its own app registration** with only the permissions it needs:

| Script | Microsoft Graph (application) | Exchange | SharePoint | AD (delegated to the gMSA) |
|---|---|---|---|---|
| Onboarding | `User.ReadWrite.All`, `LicenseAssignment.ReadWrite.All`, `UserAuthenticationMethod.ReadWrite.All` (access pass) | Exchange.ManageAsApp + *Recipient Management* | - | Create users in the employee OUs, manage role groups |
| Mover / User Attributes | - | Exchange.ManageAsApp + *Recipient Management* | - | Write user attributes, manage role groups, move within employee OUs |
| Offboarding | `User.ReadWrite.All`, `LicenseAssignment.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `Group.ReadWrite.All` (Teams and cloud groups) | Exchange.ManageAsApp + *Recipient Management* | `Sites.FullControl.All` (OneDrive handoff) | Disable, reset password, manage groups, move to Disabled OU, write `msExchHideFromAddressLists` |
| Name Change | None. The change gets to Entra ID through Entra Connect | None. Addresses are written in AD and Exchange Online reads them from there | - | Rename users, write `SamAccountName`, `UserPrincipalName`, `proxyAddresses` and `mail` in the employee OUs |
| Rollback | - | - | - | Turn accounts back on, add and remove group members, write user attributes, move between the employee and Disabled OUs |
| Inactive Accounts | `User.ReadWrite.All`, `AuditLog.Read.All` | - | - | Disable users |
| Stale Devices | `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All` | - | - | - |
| Password Expiry | `Mail.Send` (limit it to the sender mailbox with an application access policy) | - | - | Read users |
| Mailbox Quota | `Mail.Send` (limit it to the sender mailbox) | *View-Only Recipients* | - | - |
| Audits | `User.Read.All`, `AuditLog.Read.All`, `Directory.Read.All`, `Application.Read.All`, `Organization.Read.All`, `Policy.Read.All`, `Domain.Read.All`, `RoleManagement.Read.Directory`, `IdentityRiskyUser.Read.All`, `Group.Read.All` | *View-Only Recipients* | - | Read users |
| Requests | `Sites.Selected` (only the HR site), `Mail.Send` (sender mailbox) | - | - | Unlock, reset password, manage `RequestableGroups` only |
| Incident Response | `User.ReadWrite.All`, `AuditLog.Read.All`, `UserAuthenticationMethod.Read.All`, `DelegatedPermissionGrant.ReadWrite.All` (to remove app access the user gave) | *Mail Recipients* | - | Disable, reset password |
| User Activity | `AuditLog.Read.All`, `User.Read.All` | - | - | Read users. Event Log Readers on the PDC (optional) |
| AD Structure | - | - | - | **Domain Admin, once per client.** See below |

AD rights are **given on specific OUs only**, not Domain Admin.

The one exception is **AD Structure**. It creates OUs and groups at the top of the domain, and
`redirusr` / `redircmp` change a setting on the domain itself. So it needs Domain Admin. That's fine
because a domain admin runs it by hand once when setting up a new client. The automation account never
needs it.

---

## Guard rails in the code

- **Protected accounts:** offboarding and role changes won't touch admin accounts (AD `adminCount = 1`) or anyone in `ProtectedAccounts`, unless IT runs the script by hand with `-AllowProtected`. HR requests can never touch them.
- **Approvals are checked, not trusted:** the request queue looks at the list item's version history. The change to *Approved* has to come from someone in `Approvers`, and it can't be the same person who made the request.
- **No taking over accounts:** onboarding never reuses an existing account unless the Employee ID matches. Otherwise it picks the next free username.
- **Stops when things go wrong in a row:** if 5 people in a row fail (`MaxConsecutiveFailures`), the whole run stops. That usually means something is broken, like an expired certificate or a removed permission, so it's better to stop than keep failing. Everyone it didn't get to is listed as **Stopped** in the report.
- **Dry run by default**, a before and after copy of every change, and a safety stop if too many accounts would be disabled at once.

---

## Rotation

| What | How often | Reminder |
|---|---|---|
| App certificate | Every 12 months (script default) | `Audits -Check AppCredentials` flags it 30 days before it expires |
| Webhook URLs and API keys | When someone with access leaves, or once a year | Update the vault entry. Configs don't change |
| gMSA password | Automatic (every 30 days) | - |

---

## How long things are kept

Reports and before/after copies have personal info in them (names, groups, managers), so they get deleted after a while:

| What | Kept for | How |
|---|---|---|
| Reports, before/after copies, access review sheets | 90 days (`-Days`) | [`Setup/Remove-OldReports.ps1`](Setup/Remove-OldReports.ps1), weekly scheduled task |
| Log files (and their `.jsonl` copies) | 365 days (`-LogDays`) | One file per day for each script. [`Setup/Remove-OldReports.ps1`](Setup/Remove-OldReports.ps1) deletes the old ones |
| Conditional Access backups | Kept. They're restore points, not personal info | `Backups/ConditionalAccess/`, gitignored |
| Incident evidence | Kept until the incident is closed, then delete by hand | `Backups/Incidents/`, gitignored |
| Temp passwords | Never saved | Only in memory |

Reports and logs are gitignored and never committed.

---

## Reporting a problem

Open a private security advisory on GitHub instead of a public issue.
