## Requests - How It Works

### Overview

HR uses a SharePoint list. The queue script reads it and runs the work.
The work is done by the same scripts IT runs by hand. The queue just turns the list item into what those scripts expect.

```
HR fills in list --> Approval --> Queue (every 15 min) --> Onboarding / Mover / Offboarding / UserAttributes
       ^                                                              |
       \---------------- Status + Result written back <---------------+
```

---

## Order

### 1. Read

**Script:** `Invoke-RequestQueue.ps1`

* Every list item with `Status = Approved`
* Items with a **When** (`EffectiveDate`) in the future are skipped until then

---

### 2. Claim it

**Function:** `Set-RequestStatus`

* Sets `Processing` before anything runs, so two runs at the same time can't both do it

---

### 3. Turn it into a row

**Function:** `ConvertTo-RequestRow`

* Turns the form fields into the same row each script already reads from a CSV

---

### 4. Run

**Function:** `Invoke-Request`

* `New hire`: `Invoke-UserOnboarding`
* `Role change`: `Invoke-UserMover`
* `Leaver`: `Invoke-UserOffboarding`
* `Update info`: `Invoke-UserAttributesUpdate`
* `Unlock account`, `Reset password`, `Group access`: the help desk actions in `Actions/`
* Turns the script's result into one plain sentence for HR

---

### 5. Write back

* `Done` or `Needs attention`, plus the result
* Temp passwords get emailed to `TempPasswordRecipient`, never saved in the list
* Alert if anything needs attention

---

## Why a SharePoint list and not a custom website

* HR already has it, and it works in Teams and on phones
* Sign-in, permissions and version history come free with Microsoft 365
* No server to host, patch or secure (a website that can disable accounts is a big target)
* Power Automate adds approvals with no code
