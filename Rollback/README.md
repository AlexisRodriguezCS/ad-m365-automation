# Restore from Snapshot

Puts a user back the way a **before** copy says they were. For mistakes: the wrong person got offboarded, a role change has to be undone, or attributes got changed by accident.

Every script that changes a user (except onboarding) saves `Reports/Snapshots/<Script>_<date>/<user>_before.json` first. This script uses that file.

How it works inside: [Docs/Rollback.md](Docs/Rollback.md)

---

## Steps

1. Read the before copy
2. Look at the user as they are today
3. Plan **only what's different**:
   1. Turn the account back on (if it was on)
   2. Put back title, department, manager and description
   3. Add back groups they had, and remove groups they didn't have
   4. Move them back to their old OU (last, because moving changes the account's path)
4. Run the plan with retries
5. Write a report, with a **DO BY HAND** list for things AD can't put back:
   * Licenses (give them again in Microsoft 365)
   * Mailbox type (convert it back from shared)

Step 4 only runs with `-Apply`. If the user already matches the before copy, it says `NoChange`.

---

## Usage

Preview:
```powershell
.\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json
```
Restore:
```powershell
.\Rollback\Restore-FromSnapshot.ps1 -SnapshotFile .\Reports\Snapshots\Offboarding_20260919_101500\jdoe_before.json -Apply
```

Before copies are kept for 90 days (see [SECURITY.md](../SECURITY.md)). A user that was deleted from AD can't be restored this way. Use the AD Recycle Bin for that.

**No alerts.** The scheduled scripts send alerts because nobody is watching them. This one is run by hand, so the result is on screen and in `Reports/RestoreReport_*.txt`. Anything it couldn't do (licenses, mailbox type) is listed under **DO BY HAND**.
