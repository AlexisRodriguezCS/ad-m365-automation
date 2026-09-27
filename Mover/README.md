# Mover (Role Change)

When someone changes job, department or manager: update their details and change their access to match the new role.
Old role access gets removed, so people don't keep the permissions from every job they've ever had.

How it works inside: [Docs/Mover.md](Docs/Mover.md)

---

## Steps

1. Read the request (one person or a CSV)
2. Check the username, title, department, role and manager (skip bad rows)
3. Find the user and the new manager in AD
4. Work out the new access with the **same rules as onboarding**
5. Build the plan: only what's different from today
6. Save a **before** copy
7. Update title, department and manager
8. Add the new role groups
9. Remove the old role groups
10. Move them to the new department OU
11. Swap the Microsoft 365 license, if the client ties roles to licenses (`RoleLicenseSkuIds`)
12. Swap the department email lists (All Staff is never touched)
13. Save an **after** copy
14. Write a report to `Reports/`

Steps 6-13 only run with `-Apply`.

Only groups that start with `GRP_ROLE_` get added or removed (you can change this with `ManagedGroupPrefix`).
Anything someone gave by hand stays.

Licenses work the same way. Only the licenses listed in `RoleLicenseSkuIds` get swapped, so a Visio or Project license bought separately is left alone. If you leave the setting out, licenses aren't touched at all.

```json
"RoleLicenseSkuIds": {
    "Accountant":        "22222222-2222-2222-2222-222222222222",
    "Finance PowerUser": "33333333-3333-3333-3333-333333333333"
}
```

---

## Usage

**One person**
```powershell
.\Mover\Mover.ps1 -Client "ClientA" -SamAccountName lisataylor -Title "Finance Manager" -Department Finance -Role "Finance PowerUser" -Manager bobwilliams
```

**Many people**
```powershell
.\Mover\Mover.ps1 -Client "ClientA" -Path .\Mover\Data\test.csv
```

Add `-Apply` to make the changes.

---

## CSV

| SamAccountName | Title | Department | Role | Manager | EmploymentType |
|---|---|---|---|---|---|
| lisataylor | Finance Manager | Finance | Finance PowerUser | bobwilliams | Regular Full-Time |

`Manager` is the manager's username. It uses the client's `Onboarding.json` (same groups, email lists and OUs).
