# Name Change

Someone got married, divorced, or legally changed their name. This updates the name everyone sees, and if you want, their username and email too, **without losing mail sent to the old address**.

How it works inside: [Docs/NameChange.md](Docs/NameChange.md)

---

## Steps

1. Read the request (one person or a CSV)
2. Check it: the username exists, something is really changing, and the names have no characters AD won't take
3. Find the user in AD, work out the new name, and make sure the new username isn't already taken
4. Plan only what's different
5. Save a **before** copy
6. Rename: first name, last name, display name and the AD object's name
7. Change how they sign in (only if you gave a new username): username and Microsoft 365 sign-in
8. Update email: the new address becomes the main one, and **the old one stays as an alias**
9. Start an Entra Connect sync, so Microsoft 365 sees it now instead of in 30 minutes
10. Save an **after** copy
11. Write a report to `Reports/`

Steps 5-10 only run with `-Apply`. Admin and VIP accounts are refused unless IT adds `-AllowProtected`.

---

## Usage

**Just the name** (keeps the username and email, the safest option)
```powershell
.\NameChange\Set-UserName.ps1 -Client "ClientA" -SamAccountName jsmith -NewLastName "Johnson"
```

**Name, username and email**
```powershell
.\NameChange\Set-UserName.ps1 -Client "ClientA" -SamAccountName jsmith -NewLastName "Johnson" -NewUsername jjohnson
```

**Many people**
```powershell
.\NameChange\Set-UserName.ps1 -Client "ClientA" -Path .\NameChange\Data\test.csv
```

These are all dry runs (no changes). Add `-Apply` to make the changes.

---

## CSV

| SamAccountName | NewFirstName | NewLastName | NewUsername | KeepOldEmail |
|---|---|---|---|---|
| jsmith | | Johnson | jjohnson | Yes |
| mgarcia | Maria | | | Yes |

Leave a cell empty to keep what's there. An empty `NewUsername` means they keep signing in the same way.

---

## What to tell the person

A new username changes how they sign in, so warn them first:

* From now on they sign in with the **new** username. The old one stops working
* Phones, saved passwords, mapped drives and VPN profiles with the old username need updating
* Mail sent to the old address still arrives (it becomes an alias), but replies go out **from** the new address

Keeping the same username avoids all of that. The display name still updates everywhere, and for most name changes that's the right choice.

---

## Notes

* Teams and Outlook can take a few hours to show the new name. AD is updated right away
* The old email address is kept unless the request says not to (`-DropOldEmail`, or `KeepOldEmail = No`)
* Safe to run again: a rename that already happened is reported as already done, not done twice
* If something goes wrong, [Rollback](../Rollback/README.md) puts it back from the before copy
* Only works for users that live in AD. Cloud-only users aren't supported yet
