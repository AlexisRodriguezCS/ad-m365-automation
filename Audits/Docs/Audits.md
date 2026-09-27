## Audits - How It Works

### Overview

Every check is a function that returns **findings**. A finding is one row:

| Field | Meaning |
|---|---|
| `Check` | Which audit |
| `Name` | User, app, role or license |
| `Detail` | What was found |
| `Flagged` | `true` means it needs attention |
| `Reason` | Why it was flagged, in plain words |

`Export-AuditReport` turns the findings into a text summary (flagged ones first) and a CSV.
`Invoke-Audit` runs the checks you picked, one at a time, and keeps going if one fails.

---

## Checks

### ADHealth - `Get-ADHealthAudit`

* Reads: AD (domain, forest, DCs, replication), and each DC over CIM (services, disks, shares, clock)
* Flags:
  * Only one domain controller (if it dies, nobody signs in until it's restored)
  * A FSMO role held by a server that isn't a DC any more (it has to be seized)
  * AD never backed up, or not in `MaxBackupAgeDays` (default 7). It reads the `dSASignature` backup marker, same as `repadmin /showbackup`. Version 1 means never backed up, because that's what AD writes when the domain is created
  * Any of NTDS, DNS, Netlogon, Kdc, W32Time, DFSR or ADWS not running
  * A disk under `MinFreeDiskPercent` free (default 15)
  * SYSVOL or NETLOGON not shared (Group Policy won't apply from that DC)
  * A DC clock more than `MaxTimeSkewSeconds` off (default 60. Kerberos breaks at 5 minutes)
  * Replication failing, or no replication from a partner in `MaxReplicationHours` (default 24)
  * The PDC using its own clock or the Hyper-V host for time instead of an outside time server
* A DC it can't reach is one flagged row, and the rest of the DCs are still checked
* Only needs AD, so it runs for clients with no Microsoft 365

### GroupPolicy - `Get-GroupPolicyAudit`

* Reads: every GPO from AD (version numbers, status, links) and each GPO's `GPT.INI` in SYSVOL. It reads AD directly because `Get-GPO` in PowerShell 7 comes back without version numbers
* Backs up every GPO with `Backup-GPO -All` to `Backups/GroupPolicy/<date>/`, plus a `gpos.json` list to compare against next time. It only takes a new backup on the first run or when something changed, so the folder doesn't fill up with copies
* Flags:
  * A GPO added, edited (version went up), turned on or off, renamed, or linked somewhere new since the last backup
  * A GPO deleted since the last backup, with the exact `Import-GPO` command to bring it back
  * A GPO linked nowhere (it does nothing), an empty GPO, or one with every setting turned off
  * AD and SYSVOL versions that don't match (SYSVOL probably isn't replicating), or a `GPT.INI` it can't read
  * Default Domain Policy or Default Domain Controllers Policy missing
* Needs the GroupPolicy module (RSAT, or run it on a DC) for `Backup-GPO`
* Only needs AD, so it runs for clients with no Microsoft 365
* Tested on the lab DC: first backup, nothing changed, a GPO added, edited, linked and deleted, then restored with the command from the report

### Mfa - `Get-MfaAudit`

* Reads: the Graph MFA registration report
* Flags: no MFA set up, or an admin with only SMS, phone call or email

### AdminRoles - `Get-AdminRoleAudit`

* Reads: Graph directory roles and their members
* Flags: more than `MaxGlobalAdmins` Global Admins (default 4), or a guest with a role

### MailForwarding - `Get-MailForwardingAudit`

* Reads: Exchange mailboxes and inbox rules
* Flags: forwarding or an inbox rule sending mail to a domain that isn't ours

### PrivilegedAccess - `Get-PrivilegedAccessAudit`

* Reads: Graph role definitions, and active and eligible role assignments (PIM)
* Only looks at powerful roles (Global, Privileged Role, Security, Exchange, SharePoint, User, Application, Intune, Hybrid Identity admins...)
* Flags: a permanent assignment (`Assigned` with no end date), except `BreakGlassAccounts`
* Listed but not flagged: roles turned on through PIM, and PIM-eligible roles

### RiskyUsers - `Get-RiskyUserAudit`

* Reads: Entra ID Protection risky users (needs Entra ID P2)
* Flags: every user at risk or confirmed hacked, with a next step based on how risky

### Groups - `Get-GroupHygieneAudit`

* Reads: Graph groups (cloud only, since synced groups are managed in AD), their owners and members
* Labels each one as a Team, Microsoft 365 group, distribution list or security group
* Flags: no owner, or no members for more than 30 days

### SharedMailboxes - `Get-SharedMailboxAudit`

* Reads: Exchange shared mailboxes, who has FullAccess, and who has SendAs
* Flags: sign-in not blocked on the shared mailbox, a disabled account that still has access, or nobody has access

### ExternalSharing - `Get-ExternalSharingAudit`

* Reads: all SharePoint sites (OneDrive too) and the tenant's guests, a page at a time
* Sites with sharing turned off are skipped. The rest are listed with their sharing level
* Flags a site: `ExternalUserAndGuestSharing`, meaning "anyone with the link" works with no sign-in
* Flags a guest: domain not in `AllowedSharingDomains` (if you set it), or invited more than `ExternalUserMaxAgeDays` days ago (default 365)
* Connects to the SharePoint admin site, so `SharePointAdminUrl` has to be in the config

### EmailSecurity - `Get-EmailSecurityAudit`

* Reads: verified domains from Graph (skips `*.onmicrosoft.com`) and public DNS
* Flags SPF: missing, more than one record, `+all` or `?all`
* Flags DMARC: missing, or `p=none` (only monitoring)
* Flags DKIM: no `selector1` / `selector2` CNAME (that's how Microsoft 365 publishes DKIM keys)

### ConditionalAccess - `Get-ConditionalAccessAudit`

* Reads: every Conditional Access policy from Graph, as raw JSON
* Saves `Backups/ConditionalAccess/policies_<date>.json` every run. It's outside `Reports/`, so the 90-day cleanup doesn't delete it
* Compares with the last backup by policy ID and `modifiedDateTime`
* Flags: a new policy, a changed policy (including turned on or off, like enabled to report-only), or a deleted policy
* The first run just saves a starting point

### AppCredentials - `Get-AppCredentialAudit`

* Reads: Graph app registrations (secrets and certificates)
* Flags: expired, or expiring within `CredentialWarningDays` (default 30)

### Licenses - `Get-LicenseAudit`

* Reads: Graph licenses and users
* Flags: paid licenses nobody uses, and licenses on disabled accounts or accounts idle for `InactiveDays`
* Also: monthly cost per department

### AccessReview - `Get-AccessReview`

* Reads: AD users under `DefaultOU`, with their manager and groups
* Makes: one CSV per manager with an empty `Decision` column (Keep or Remove)
* Flags: users with no manager

### OffboardingCheck - `Get-OffboardingCheck`

* Reads: the HR leavers CSV, AD and Graph
* Flags: still enabled, still in groups, still licensed
