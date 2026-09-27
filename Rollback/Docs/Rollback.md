## Rollback - How It Works

### Overview

Puts a user back the way a **before** copy says they were. Every script that changes a user saves one of those first, so undoing it is just the difference between "then" and "now".

---

## Order

### 1. Read the before copy

**Function:** `New-RestorePlan`

* Loads `Reports/Snapshots/<Script>_<date>/<user>_before.json`
* Stops with an error if it has no AD section, since there's nothing to restore from
* Loads the user as they are **today**. The plan is the difference, not a blind replay of the file

---

### 2. Plan (the order matters)

1. **EnableAccount**: first, so nothing else is done on a disabled account
2. **SetAttribute**: title, department, manager and description, using the shared `Get-UserAttributeChanges`, so only values that are really different get touched
3. **AddToGroup / RemoveFromGroup**: groups back to exactly what the before copy had
4. **MoveToOU**: last, because moving changes the DN every earlier step used

Empty values in the before copy are skipped. AD can't "set" a value to nothing.

---

### 3. Things AD can't undo

Listed in the report under **DO BY HAND**, and never tried:

* **Licenses**: give them again in Microsoft 365. The before copy says which ones they had
* **Mailbox type**: turning a shared mailbox back into a user mailbox needs a license and a person to decide

---

### 4. Make the changes

* Runs through the shared `Invoke-Plan` retry engine
* Ends as `Restored`, `NoChange` or `Failed`
* Report: `Reports/RestoreReport_<date>.txt`

---

## Limits

* A user **deleted** from AD can't be restored this way. Use the AD Recycle Bin first, then run this to put their groups and attributes back
* Before copies are kept 90 days (see [SECURITY.md](../../SECURITY.md))
* No alerts. Someone runs this by hand and watches the output, unlike the scheduled scripts

---

## Usage

```powershell
# Preview
.\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json

# Restore
.\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json -Apply
```
