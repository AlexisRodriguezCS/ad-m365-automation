## Mover - How It Works

### Overview

Handles role changes. It uses the same rules as onboarding (who gets what) and compares that to what the user has today.
Only the difference gets changed.

---

## Order

### 1. Request

**Function:** `New-MoverRequest`

* Turns a CSV row or the parameters into a pipeline object

---

### 2. Check

**Function:** `Test-MoverData`

* Username, title, department and role are required
* Department has to be one of the `Departments` in the config (and uses the config's spelling)
* Sets `Status` to `Valid` or `Invalid`

---

### 3. Find the user

**Function:** `Get-MoverIdentity`

* Finds the user and the new manager in AD
* Saves their current title, department, manager and groups
* Sets `Status` to `NotFound` if the user doesn't exist

---

### 4. Rules

**Function:** `Set-OnboardingPolicy` (from onboarding)

* Same rules as a new hire in that role: groups and email lists

---

### 5. Plan

**Function:** `New-MoverPlan`

* Compares new vs current and only plans the changes:

  * `SetAttribute` (one for each value that changed)
  * `AddToGroup`
  * `RemoveFromGroup`
  * `MoveToDepartmentOU`
  * `SwitchLicense` (only when `RoleLicenseSkuIds` has a license for the new role)
  * `SyncDistributionLists`

New access is added before old access is removed, and the OU move happens after the group changes.

**Licenses** follow the same rule as role groups. Only licenses listed in `RoleLicenseSkuIds` are managed, so a Visio or Project license bought separately is never removed. `Switch-MoverLicense` adds the new license and removes the old one **in one `Set-MgUserLicense` call**. If there's a moment with no license at all, Microsoft 365 can start its 30-day timer to delete the mailbox. If the account has no usage location, it sets one first, because a license can't be given without it.

---

### 6. Make the changes (`-Apply` only)

**Function:** `Start-Mover`

* Before and after copy of the account
* Runs the plan with retries (shared `Invoke-Plan`)
* Sets `Status` to `Moved` or `Failed`

---

### 7. Report

**Function:** `New-Report` (shared)

---

## Summary

```
Request: one person or a CSV

Check: is the new role valid

Find: what they have in AD today

Rules: what the new role should have

Plan: the difference between new and current

Change: attributes, add groups, remove groups, move OU, swap email lists

Report: what happened, pass or fail
```
