# Compromised Account Response

The "someone got phished" steps, as one command. IT runs it by hand as soon as they think an account is hacked.

How it works inside: [Docs/IncidentResponse.md](Docs/IncidentResponse.md)

---

## Steps

1. Find the user in Entra (cloud only, or synced from AD)
2. **Save evidence first** (always, even without `-Apply`), in `Backups/Incidents/<user>_<date>/`:
   * `inbox-rules.json`: every inbox rule
   * `sign-ins.csv`: sign-ins from the last 7 days (time, IP, country, app, result)
   * `mfa-methods.json`: the MFA methods they have and when each was added
   * `oauth-grants.json`: apps the user gave access to
   * Mailbox forwarding settings
3. Plan what to lock down
4. Save a **before** copy
5. **Disable the account** (in AD for synced users, so the next sync doesn't turn it back on, and in Entra)
6. **Reset the password** to a long random one nobody knows
7. **Sign out every session** (refresh tokens revoked)
8. **Remove app access the user gave.** An app with its own token keeps reading their mail even after the account is disabled
9. **Remove mailbox forwarding**
10. **Turn off suspicious inbox rules**: ones that forward, redirect, delete, or move mail to folders nobody checks (RSS Feeds, Conversation History, Archive...). Turned off, not deleted, so they stay as evidence
11. Save an **after** copy
12. Write a report with a **FOLLOW UP** list for a person:
    * MFA methods added recently (attackers add their own so they can get back in)
    * Sign-ins from more than one country
    * Check sent items and recently shared files
    * Give the user new sign-in details once it's safe
13. Send an alert to the team (always, an incident is never normal)

Steps 4-10 only run with `-Apply`. If one step fails, the rest still run. Partly locked down is better than wide open.

---

## Usage

Evidence only (changes nothing):
```powershell
.\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com
```
Lock it down:
```powershell
.\IncidentResponse\Invoke-CompromisedAccountResponse.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com -Apply
```
Look further back: `-SignInDays 30`

---

## Config (`IncidentResponse.json`)

Just the sign-in details and optional alerts:
```json
{
    "TenantDomain": "contoso.onmicrosoft.com",
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000",
    "AlertWebhookUrl": "secret:ClientA-TeamsWebhook"
}
```

Permissions: Graph `User.ReadWrite.All`, `AuditLog.Read.All`, `UserAuthenticationMethod.Read.All`, `DelegatedPermissionGrant.ReadWrite.All` (to remove app access). Exchange *Mail Recipients*. AD: disable and reset passwords in the user OUs.

Protected accounts are **not** blocked here, on purpose. A hacked admin is exactly who you need to lock out.
