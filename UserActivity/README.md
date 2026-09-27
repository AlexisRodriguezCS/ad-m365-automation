# User Activity

"My password doesn't work." "I got locked out." "I can't get into Teams."
One command shows everything that happened to the account as one timeline, with a **plain English summary at the top**. Read-only.

How it works inside: [Docs/UserActivity.md](Docs/UserActivity.md)

---

## What it looks at

| Source | What you find out |
|---|---|
| **Entra sign-ins** | Every sign-in, worked or failed, with the error in plain words (wrong password, locked, expired, MFA not finished, blocked by Conditional Access and which policy), plus the app, device, IP and location |
| **Entra audit logs** | Self-service password resets (SSPR), admin resets, password changes, MFA methods added, group changes, and who did them |
| **AD** (synced users) | Locked out right now, when the password was last set, password expired or about to, last wrong password |
| **Lockout source** (optional) | Which computer or device caused the lockout (event 4740 on the PDC), like an old phone with a saved password |

---

## Steps

1. Find the user in Entra
2. Get sign-ins and audit events for the last `-Days` (default 14, max 30, which is all Entra keeps)
3. For synced users: the AD account's state, and lockout events if `LockoutServer` is set
4. Put everything into one timeline, newest first
5. Write the **summary**:
   * Disabled, locked out (and by which device), or password expired
   * **"Password was changed on ... Since then N sign-ins failed with the old password, from Outlook on iOS (12x)"**. This is the classic "it's not working" after a reset
   * Blocked by Conditional Access (which policy), or MFA not finished
   * Last sign-in that worked, or none at all
6. Save the report (`.txt`, summary and timeline) and a `.csv` to `Reports/`

If one source can't be read (like a missing permission), the others still show, and the report says what was missing.

### Works with whatever the client has

| Client has | What you get |
|---|---|
| Hybrid (AD + Entra, P1) | Everything above |
| Entra without P1 | Audit logs and AD. The report says sign-in logs need P1 |
| No SSPR | Same. Admin resets and AD "password set" still count as password changes |
| On-prem only (`"Environment": "OnPrem"`) | AD only: lockouts and which device, password set or expired, wrong passwords. Use `-SamAccountName` |

---

## Usage

```powershell
.\UserActivity\Get-UserActivity.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com
.\UserActivity\Get-UserActivity.ps1 -Client "ClientA" -UserPrincipalName jdoe@contoso.com -Days 30
.\UserActivity\Get-UserActivity.ps1 -Client "ClientB" -SamAccountName jdoe          # on-prem only client
```

Example summary:
```
- The account is LOCKED OUT right now (since 9/18/2026 10:47 AM). Lockout came from: JDOE-IPHONE.
- Password was changed on 9/18/2026 10:02 AM (Reset password (self-service)). Since then 14 sign-in(s) failed
  with the old password, from: Exchange ActiveSync on iOS (14x). Something is still using the old password
  (phone mail app, Outlook, saved Wi-Fi/VPN or mapped drive): update it there.
- Last successful sign-in: 9/18/2026 10:05 AM (Microsoft Teams).
```

---

## Config (`UserActivity.json`)

```json
{
    "LockoutServer": "DC01.contoso.local",
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000"
}
```

`LockoutServer` is the PDC emulator (`(Get-ADDomain).PDCEmulator`). Leave it out to skip finding the lockout device.
Graph: `AuditLog.Read.All`, `User.Read.All` (sign-in logs need Entra ID P1). AD: read users, and *Event Log Readers* on the PDC for lockout devices.
