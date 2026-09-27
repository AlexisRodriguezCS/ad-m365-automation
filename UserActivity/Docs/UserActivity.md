## User Activity - How It Works

### Overview

Read-only. It gets data from three places, puts it in one timeline, and then works out what the user is really running into. The [README](../README.md) covers what it shows. This page covers how it decides.

---

## Order

### 1. Get the data

| Function | Source | Notes |
|---|---|---|
| `Get-SignInEvents` | Entra sign-in logs | Needs Entra ID P1. Failed sign-ins keep their error code |
| `Get-AuditEvents` | Entra audit logs | Password resets (self-service and admin), MFA changes, group changes |
| `Get-AdAccountEvents` | On-prem AD | Lockout state, when the password was set and when it expires, plus event 4740 on `LockoutServer` to find the device that caused a lockout |

Each source is handled on its own. A missing permission or a tenant without P1 loses that one source, not the whole report. Everything is turned into the same event shape by `New-ActivityEvent`, so the timeline sorts and prints the same way.

---

### 2. Turn codes into words

**Function:** `ConvertTo-FriendlySignInError`

Entra gives back numbers. The report shows words: `50126` is "Wrong password", `50053` is "Account locked", `50057` is "Account disabled", `53003` is "Blocked by Conditional Access", `50074` is "MFA not completed".

---

### 3. Summary

**Function:** `Get-ActivitySummary`

This is the part that answers the ticket. It looks for what's behind most "my password doesn't work" calls:

> a password change, and then sign-ins that keep failing with the **old** password

Two rules keep that accurate:

* A password **change** only counts if it really is one. It has to match `(reset|change)\b.*password` or `password (set|reset|change)`
* Events with *failed* or *wrong* in the text are left out, so "wrong password (AD)" never gets mistaken for a reset

When it finds that, the summary names the apps and devices still using the old password (`Exchange ActiveSync on iOS (14x)`), because that's what needs fixing: a phone mail app, a saved Wi-Fi or VPN profile, or a mapped drive.

It also says: disabled right now, locked out right now and from which device, password expired, blocked by Conditional Access and which policy, MFA not finished, and the last sign-in that worked.

---

### 4. Report

**Function:** `Invoke-UserActivityReport`

* `Reports/UserActivity_<user>_<date>.txt`: summary first, then the timeline, newest first
* `Reports/UserActivity_<user>_<date>.csv`: the same events for Excel
* The summary also prints on screen, so the help desk usually doesn't need to open the file

---

## Environments

`Get-UserActivity.ps1` has two ways to call it. A client with `"Environment": "OnPrem"` in the config uses `-SamAccountName` and never touches Graph. Everyone else uses `-UserPrincipalName`. The other scripts use the same `Environment` setting to skip their Microsoft 365 steps.
