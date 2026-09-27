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
