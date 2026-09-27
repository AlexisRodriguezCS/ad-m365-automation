## Offboarding - How It Works

### Overview

Takes a list of people who are leaving and runs each one through the same steps.
It uses the same pipeline object, step runner, retries, logging and report as onboarding.

---

## Order

### 1. Import

**Function:** `Import-OffboardingCsv`

* Reads the CSV (`SamAccountName`, and `Manager` if there is one)
* Wraps each row in a pipeline object

Nothing gets changed here.

---

### 2. Check

**Function:** `Test-OffboardingData`

* `SamAccountName` is required and can only have characters AD accepts
* `Manager` is optional, but has to be a UPN
* Sets `Status` to `Valid` or `Invalid`

Bad rows are logged and skipped.

---

### 3. Find the user

**Function:** `Get-OffboardingIdentity`

* Finds the user in AD (read-only, so it runs in a dry run too)
* Saves:

  * `DistinguishedName`
  * `MemberOf`
  * `DisplayName`
  * `EntraUPN`
* Sets `Status` to `NotFound` if the account doesn't exist

---

### 4. Plan

**Function:** `New-OffboardingPlan`

* Builds the list of actions, in this order:

  * `DisableAccount`
  * `RevokeSessions`
  * `RetireDevices` (Intune: remove company data from phones and laptops)
  * `RemoveFromGroup` (one for each group)
  * `MoveToDisabledOU`
  * `RemoveFromDistributionLists`
  * `RemoveFromCloudGroups` (Teams, Microsoft 365 and cloud security groups. The manager takes over teams where the leaver was the only owner)
  * `ConvertMailbox`
  * `SetAutoReply`
  * `GrantMailboxAccess` (only with a manager)
  * `ShareOneDrive` (only with a manager)
  * `HideFromAddressBook`
  * `RemoveLicenses`
* Fills in `.Plan`

Nothing gets changed here either. In a dry run it stops here.

---

### 5. Make the changes (`-Apply` only)

**Function:** `Start-Offboarding`

* Runs each action with retries, waiting a bit longer each time
* Stops if the account can't be disabled
* Any other failure is recorded, and the rest of the plan still runs
* Sets `Status` to `Offboarded` or `Failed`

---

### 6. Report

**Function:** `New-Report` (shared)

Writes a report to `Reports/` with what happened to each user.

---

## Rules it follows

* Disable first, clean up after
* Convert the mailbox before removing the license, or the mailbox gets deleted
* Every action is safe to run again
* Group memberships are logged before they're removed, so they can be put back

---

## Summary

```
Import: read the CSV

Check: SamAccountName and Manager

Find: the user in AD

Plan: the list of actions

Change: disable, remove access, hand off mailbox and OneDrive, remove licenses

Report: what happened, counts, pass or fail
```
