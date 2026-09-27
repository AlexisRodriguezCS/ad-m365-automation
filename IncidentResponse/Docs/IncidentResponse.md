## Incident Response - How It Works

### Overview

The "someone got phished" steps, done in seconds instead of from memory. **Evidence is saved before anything changes**, because locking the account down wipes out the traces of what the attacker did.

---

## Order

### 1. Who

**Function:** `Get-IncidentIdentity`

* Finds the account in Entra
* Notes if it's synced from AD. A synced account has to be disabled and reset **in AD**, not in the cloud, or the next sync undoes it

---

### 2. Evidence (always, even in a dry run)

**Function:** `Save-IncidentEvidence`

Saved in `Backups/Incidents/<user>_<date>/`. That's outside `Reports/`, so the 90-day cleanup never deletes it.

| File | What's in it | Why |
|---|---|---|
| `inbox-rules.json` | Every inbox rule and where it sends mail | Attackers add rules to forward, delete or hide mail |
| `sign-ins.csv` | Sign-ins for the last `-SignInDays` days: time, IP, app, country, result | Shows where they got in from |
| `mfa-methods.json` | The MFA methods on the account and when each was added | Attackers add their own so they can come back |
| `oauth-grants.json` | Apps the user said yes to, and what each one can do | An approved app has its own token and keeps working after the password changes |

---

### 3. Plan

**Function:** `New-IncidentPlan`

The order matters: lock the attacker out first, then stop data leaving.

1. **DisableAccount**
2. **ResetPassword**: random, nobody is told what it is
3. **RevokeSessions**: tokens that already exist keep working until they're revoked, so without this a disabled account can still be used
4. **RevokeAppConsents**: apps the user approved
5. **RemoveForwarding**: if the mailbox forwards outside
6. **DisableInboxRule**: one per suspicious rule. Rules that forward, redirect, delete, or move mail into a folder nobody reads (RSS Feeds, Conversation History, Archive, Junk)

Rules are **turned off, not deleted**, so they stay as evidence.

### Why app access matters

A lot of phishing pages now don't ask for a password. They ask the user to approve an app, like a "Document Viewer" that wants `Mail.Read` and `offline_access`. The user clicks Accept, and the app gets **its own refresh token**.

That token doesn't care that you disabled the account, reset the password and signed out every session. It keeps reading their mail until the approval is removed. That's why this step exists.

Only the user's **own** approvals get removed (`consentType = "Principal"`). An approval marked `AllPrincipals` is an admin approval for the whole company. Removing that during an incident would cut every employee off a real app, and turn one hacked mailbox into an outage for everyone.

---

### 4. Lock down (`-Apply` only)

* A before and after copy is saved in the same evidence folder
* Every step goes through the shared retry engine
* If one step fails, the rest still run. Partly locked down is better than wide open
* Ends as `Contained` or `Failed`

---

### 5. Follow up

The report ends with the things only a person can decide:

* MFA methods added during that time: check they really belong to the user
* Sign-ins from more than one country
* Check sent items and anything shared recently
* Give the user a new password or a Temporary Access Pass once you're sure the attacker is out

An alert is **always** sent, whether it worked or not. An incident is never normal.

---

## Usage

```powershell
# Evidence only, changes nothing
.\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com

# Lock it down
.\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com -Apply
```

---

## Permissions

Graph: `User.ReadWrite.All`, `AuditLog.Read.All`, `UserAuthenticationMethod.Read.All`, `DelegatedPermissionGrant.ReadWrite.All`. Exchange: `Exchange.ManageAsApp` with *Mail Recipients*.
