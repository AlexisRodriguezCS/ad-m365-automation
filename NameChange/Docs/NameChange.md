## Name Change - How It Works

### Overview

A rename is riskier than changing an attribute. It changes the account's own name (CN), how they sign in, and the email address every outside contact has. This script does it in an order that never leaves the account half renamed, and never quietly loses mail.

---

## Order

### 1. Request

**Function:** `New-NameChangeRequest`

* Turns a CSV row or the parameters into a pipeline object
* `KeepOldEmail` is **true** by default, because mail sent to the old address has to keep arriving

---

### 2. Check

**Function:** `Test-NameChangeData`

* The username is valid, and something is really changing
* Names can't have `, \ # + < > ; " =` in them, because AD won't take those in an object name
* A new username has to fit the 20 character limit for SamAccountName

---

### 3. Find the user

**Function:** `Get-NameChangeIdentity`

* Loads the user with `GivenName`, `Surname`, `DisplayName`, `proxyAddresses` and `adminCount`
* Admin and VIP accounts are refused unless IT adds `-AllowProtected`
* Only the parts you give are changed. An empty first name keeps the current one
* **The new username has to be free.** If someone else has it, the request is `Invalid`. Two accounts fighting over one username is a much worse problem than a rename that didn't happen
* The part after the @ comes from the account's current UPN, so companies with more than one domain keep the right one

---

### 4. Plan

**Function:** `New-NameChangePlan`

| Action | When |
|---|---|
| `RenameAccount` | The first name, last name or display name is different (capital letters count, so fixing capitals is a change) |
| `ChangeLogonName` | A new username was given |
| `UpdateEmail` | A new username was given (the email address follows the username) |
| `SyncToEntra` | Anything is changing |

If nothing is different, it's `NoChange` and the account isn't touched.

---

### 5. Make the changes

**Function:** `Start-NameChange`, which uses the shared `Invoke-Plan`

`RenameAccount` is the step that **stops everything if it fails**. Every step after it uses the renamed account, so if the rename fails, nothing else runs.

| Action | What it does |
|---|---|
| `Rename-UserAccount` | Sets `GivenName`, `Surname` and `DisplayName`, then runs `Rename-ADObject` for the CN. It also updates the DN it's holding, because renaming the object changes the path every later step needs |
| `Set-UserLogonName` | Sets `SamAccountName` and `UserPrincipalName` together. Returns `AlreadyRenamed` if an earlier run already did it, so running again is safe. Logs a **warning**, because the old username stops working the moment this runs |
| `Update-UserEmailAddress` | Rewrites `proxyAddresses`: the new address becomes `SMTP:` (main), the old main one becomes `smtp:` (alias). In a hybrid setup Exchange Online reads these from AD, so AD is the right place to change them |
| `Invoke-EntraSync` | Starts a delta sync. Only tries twice. If it fails, the normal scheduled sync picks up the change anyway |

Before and after copies are saved in `Reports/Snapshots/NameChange_<date>/`, so [Rollback](../../Rollback/README.md) can undo the whole thing.

---

## Why the old email address is kept

Removing it looks cleaner, but it quietly breaks things. Every outside contact, mailing list, invoice site and saved contact still has the old address. Mail to it bounces, and nobody tells the person. They just stop hearing from people. Keeping it as an alias costs nothing: new mail goes out from the new address, and mail to the old one still arrives.

`-DropOldEmail` is there for the rare case where the old address has to go.

---

## Not covered

* **Cloud-only users.** This writes to AD. A cloud-only tenant would need `Update-MgUser`. See "Cloud only clients" in the roadmap
* **Teams and Outlook caches.** AD updates right away, the apps can take a few hours
* **Old certificates or email signatures** with the old name in them
