# Offboarding

Removes access for people who are leaving, and gives their mailbox and OneDrive to their manager.

How it works inside: [Docs/Offboarding.md](Docs/Offboarding.md)

---

## Steps

1. Read the CSV
2. Check `SamAccountName` and `Manager` (skip bad rows)
3. Find the user in AD (skip if not found)
4. Build the plan
5. Disable the AD account, reset the password to a random one, and write a note in the description
6. Sign the user out of every Microsoft 365 session
7. Remove company data from their phones and laptops (Intune retire, personal data is left alone)
8. Remove them from every AD group (logged, so it can be put back)
9. Move them to the Disabled OU
10. Remove them from cloud email lists
11. Remove them from Teams, Microsoft 365 groups and cloud security groups (which also removes them from those teams' SharePoint sites). If they were a team's **only owner**, the manager becomes owner first. With no manager, the report flags the team
12. Turn the mailbox into a shared mailbox
13. Turn on an out of office pointing to the manager (or `DefaultContact`)
14. Give the manager full access to the mailbox
15. Give the manager access to the OneDrive
16. Hide them from the address book (people can't pick them for new email, but the manager still has the mailbox)
17. Remove all Microsoft 365 licenses
18. Write a report to `Reports/`

A **before** and **after** copy of the user (groups, licenses, mailbox, OU...) is saved to `Reports/Snapshots/` around steps 5-17.

Steps 5-17 only run with `-Apply`. Steps 14-15 only run when a `Manager` is given.

**Why this order:** lock them out first (5-7), then remove access (8-11), then hand off their data and hide them (12-16). Licenses go last, because removing them before the mailbox is converted would delete the mailbox.

---

## Usage

**One person** (also the emergency option, it runs right away)
```powershell
.\Offboarding\Offboarding.ps1 -Client "ClientA" -SamAccountName johnsmith -Manager maryjohnson@contoso.com
```

**Many people**
```powershell
.\Offboarding\Offboarding.ps1 -Client "ClientA" -Path .\Offboarding\Data\test.csv
```

These are dry runs (no changes). Add `-Apply` to make the changes.

**Scheduled** (like their last day at 5 PM): HR sends a Leaver request with a "When" time. See [Requests](../Requests/README.md).

---

## CSV

| SamAccountName | Manager |
|----------------|---------|
| johnsmith | maryjohnson@contoso.onmicrosoft.com |
| lisataylor | |

---

## Notes

* The Disabled OU has to stay in Entra Connect's sync scope. If it's left out, the Entra user gets deleted, and the mailbox with it.
* OneDrives with no license are kept based on your retention policy. Plan to archive or delete them once the manager is done.
* Permissions: Graph `User.ReadWrite.All`, `LicenseAssignment.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `Group.ReadWrite.All`. Exchange `Exchange.ManageAsApp` with *Recipient Management*. SharePoint `Sites.FullControl.All` (OneDrive handoff). Full list in [SECURITY.md](../SECURITY.md).
