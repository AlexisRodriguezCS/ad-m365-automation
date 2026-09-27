# Audits

Read-only checks for security, cost and compliance. **They never change anything.**
Each check writes a short report (problems at the top) and a full CSV you can open in Excel.

Details: [Docs/Audits.md](Docs/Audits.md)

---

## Checks

| Check | What it finds | Why it matters |
|---|---|---|
| `ADHealth` | Domain controller health: only one DC, FSMO roles on a server that's gone, AD never backed up (or not lately), core services stopped, disks filling up, SYSVOL or NETLOGON missing, clock drift, PDC time source, replication failing or behind | The things that take a whole domain down, found before they do |
| `GroupPolicy` | Backs up every GPO (restorable with `Import-GPO`) whenever something changed, and flags GPOs added, edited or deleted since the last backup, GPOs linked nowhere, empty GPOs, GPOs with every setting off, AD and SYSVOL versions that don't match, and a missing default policy | A bad GPO edit can break every PC at once. The backup is how you put it back |
| `Mfa` | Users with no MFA, admins using only SMS or phone calls | The #1 way accounts get taken over. Cyber insurance asks about it |
| `AdminRoles` | Who has admin roles, too many Global Admins, guests with admin | More admins means more damage if one gets hacked |
| `MailForwarding` | Mailboxes and inbox rules sending mail outside the company | The first thing attackers set up after they get in |
| `AppCredentials` | App secrets and certificates that expired or expire in 30 days | An expired secret breaks an integration without any warning |
| `PrivilegedAccess` | Admins with **permanent** powerful roles instead of PIM (turned on only when needed). Break-glass accounts are skipped | A permanent admin is always a target. PIM makes that window small |
| `RiskyUsers` | Accounts Entra ID Protection marks as at risk or hacked, with what to do next | Microsoft catches leaked passwords and impossible travel. This makes sure someone acts on it |
| `Groups` | Cloud groups and Teams with no owner, or empty for 30+ days | Nobody reviews access in a group with no owner. Empty ones are just clutter |
| `SharedMailboxes` | Who has FullAccess or SendAs on each shared mailbox, disabled people who still have access, sign-in not blocked, mailboxes nobody can open | Shared mailboxes pick up access over the years and nobody cleans it up |
| `ExternalSharing` | SharePoint and OneDrive sites where "anyone with the link" works with no sign-in, guests from domains you didn't approve, guests invited over a year ago | Company files getting out, and old guests nobody removed |
| `EmailSecurity` | SPF, DKIM and DMARC for every domain: missing, broken (+all, two SPF records) or only monitoring | Without them anyone can send email that looks like it came from you |
| `ConditionalAccess` | Backs up every Conditional Access policy to JSON, and flags policies added, deleted or changed since the last backup | A changed policy can lock everyone out or turn MFA off. The backup lets you put it back |
| `Licenses` | Unused licenses, licenses on disabled or idle accounts, cost per department | Money. Often 10-20% of licenses are wasted |
| `AccessReview` | One sheet per manager listing their team's access (Keep or Remove), and users with no manager | Most audits require it (SOC 2, ISO 27001, HIPAA) |
| `OffboardingCheck` | Leavers who are still enabled, still in groups, or still licensed | Proves offboarding really happened |

---

## Steps (every check)

1. Connect (read-only)
2. Get the data
3. Flag anything risky, with the reason
4. Write `Audit_<Check>_<date>.txt` (NEEDS ATTENTION at the top) and a `.csv`
5. Send an alert if anything was flagged

If one check fails (for example a missing permission), the others still run.

---

## Usage

```powershell
.\Audits\Audit.ps1 -Client "ClientA"                                   # all checks
.\Audits\Audit.ps1 -Client "ClientA" -Check Licenses, Mfa              # some checks
.\Audits\Audit.ps1 -Client "ClientA" -Check ADHealth                   # domain controllers only
.\Audits\Audit.ps1 -Client "ClientA" -Check GroupPolicy                # GPO backup and changes
.\Audits\Audit.ps1 -Client "ClientA" -Check OffboardingCheck -Path .\leavers.csv
```

**Clients with no Microsoft 365** (`"Environment": "OnPrem"` in `Audits.json`): "All" runs only the checks that need just AD (`ADHealth`, `GroupPolicy`, `AccessReview`), and it never connects to Microsoft 365. Asking for a cloud check gives a clear error.

---

## Notes

* Microsoft Graph doesn't have license prices, so put them in the config (`LicensePrices`, monthly per license).
* `Mfa` and the checks based on sign-ins need Entra ID P1. `RiskyUsers` needs Entra ID P2.
* `ExternalSharing` connects to SharePoint, so `SharePointAdminUrl` has to be in the config.
* `GroupPolicy` needs the GroupPolicy module (RSAT, or run it on a DC) for `Backup-GPO`. Reading GPOs is allowed for any domain user by default.
* `ADHealth` needs to read AD, and remote WMI access to each DC (it reads services, disks, shares and the clock over CIM). Run it as a domain admin, or give the account *Remote Management Users* and WMI read on the DCs.
* Permissions (all read-only): Graph `User.Read.All`, `AuditLog.Read.All`, `Directory.Read.All`, `Application.Read.All`, `Organization.Read.All`, `Policy.Read.All`, `Domain.Read.All`, `RoleManagement.Read.Directory`, `IdentityRiskyUser.Read.All`, `Group.Read.All`. Exchange `View-Only Recipients`. Full list in [SECURITY.md](../SECURITY.md).
