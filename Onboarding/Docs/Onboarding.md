## Onboarding - How It Works

### Overview

Takes the new hire data from HR and runs it through a set of steps.
Each step does one job only.

---

## Order

### 1. Import

**Function:** `Import-OnboardingCsv`

* Reads the CSV from HR
* Wraps each row in a pipeline object
* Starts it with:

  * `Raw`
  * `Errors`
  * `Plan`
  * `Status` (`Pending`)

Nothing gets changed here.

---

### 2. Clean up

**Function:** `ConvertTo-OnboardingStandard`

* Removes extra spaces
* Fixes capital letters, but only when a value is all lowercase or ALL CAPS. Mixed case is kept as typed, so O'Brien, McDonald and "IT Manager" don't get broken
* Department gets fixed to the config's spelling (HR, IT, QA...)

It doesn't check anything yet. It just gets the data into the same shape.

---

### 3. Check

**Function:** `Test-OnboardingData`

* Checks the required fields
* Looks for missing or bad values
* Adds any problems to `.Errors`
* Sets `Status` to `Valid` or `Invalid`

Bad rows are logged and skipped.

---

### 4. Rules

**Function:** `Set-OnboardingPolicy`

* Decides:

  * Email lists (department, managers, all staff)
  * Security groups (from the role, plus the defaults)
  * License

---

### 5. Plan

**Function:** `New-OnboardingPlan`

* Turns the rules into a list of actions:

  * `WaitForEntra`
  * `AddToGroup`
  * `AssignLicense`
  * `AddToDistributionList` (after the license, because the mailbox only exists once they're licensed)
* Fills in `.Plan`

Nothing is changed in Active Directory yet.

---

### 6. Build the account details

**Function:** `New-OnboardingIdentity`

* Makes:

  * `SamAccountName` (only characters AD accepts, 20 max)
  * `UserPrincipalName`
  * `EntraUPN`
  * `DisplayName`
  * `OU`
* Finds the manager in AD by full name or username. Names with an apostrophe (O'Brien) work

Turns HR's data into the details AD needs.

---

### 7. Create the user (`-Apply` only)

**Function:** `New-OnboardingUser`

* Creates the AD user
* Sets `Status` to `Created`, or `AlreadyExists` if the account is already there

Then **`Invoke-EntraSync`** starts one delta sync for all the new users.

---

### 8. Make the changes (`-Apply` only)

**Function:** `Start-Onboarding`

* Runs each action with retries, waiting a bit longer each time
* Waits for the user to show up in Entra first
* Stops if the user never syncs

---

### 9. Report

**Function:** `New-Report` (shared)

Writes a report to `Reports/` for each user:

* Check results
* Rules
* Plan results
* Status

---

## Rules it follows

* Each step does one job
* Nothing changes in AD until the data has been checked
* Safe to run again
* Internal helper functions stay private

---

## Summary

```
Import: read the CSV

Clean up: spaces and capital letters

Check: required info is there

Rules: decide groups, email lists, license

Plan: list of actions from the rules

Build: username, UPN, display name, OU, manager

Create: create the AD user, sync to Entra

Change: run the plan (groups, email lists, license)

Report: what happened, counts, pass or fail
```
