## Inactive Accounts - How It Works

### Overview

Checks every enabled account against when it last signed in. Only reports by default.

---

## Order

### 1. Get data

**Function:** `Get-InactiveAccountData`

* All enabled users from Graph, with `signInActivity`
* Last sign-in = the newest of interactive, non-interactive and successful sign-ins

---

### 2. Check

**Function:** `Test-InactiveAccount`

* `Excluded`: on the exclude list
* `Inactive`: past the limit for employees or guests
* `Active`: everyone else

---

### 3. Plan

**Function:** `New-InactiveAccountPlan`

* Employees: `DisableAccount`
* Guests: `RemoveGuest`

---

### 4. Safety stop

**Function:** `Invoke-InactiveAccountReview`

* If more than `MaxPercentToDisable` of accounts look inactive, nothing runs and everyone is flagged

---

### 5. Make the changes (`-Apply` only)

**Function:** `Start-InactiveAccountCleanup`

* Before and after copy of each account
* Synced users are disabled in AD (AD is where they live), cloud users in Entra
* Retries through the shared `Invoke-Plan`

---

### 6. Report

* Text report (only inactive accounts) and a CSV for Excel

---

## Summary

```
Get: every enabled account + last sign-in

Check: active / inactive / excluded

Plan: disable employees, remove guests

Safety: stop if too many look inactive

Change: disable / remove

Report: who, why, what happened
```
