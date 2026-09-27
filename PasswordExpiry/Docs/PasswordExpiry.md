## Password Expiry - How It Works

### Overview

Sends reminder emails every day, and keeps a list of what was sent so each reminder only goes out once.

---

## Order

### 1. Get the data

**Function:** `Get-PasswordExpiryData`

* Enabled AD users whose password can expire
* The expiry date comes from `msDS-UserPasswordExpiryTimeComputed`

---

### 2. Check

**Function:** `Test-PasswordExpiry`

* `Expired`: already past
* `NotDue`: not close enough for any reminder
* `Invalid`: needs a reminder but has no email address
* `AlreadySent`: this reminder is already on the sent list
* `Due`: send it

It picks the reminder with "days left is at or under the reminder day", not "days left is exactly the reminder day". So if a run gets missed, the next one catches up.

---

### 3. Plan

**Function:** `New-PasswordExpiryPlan`

* `SendReminder`

---

### 4. Send (`-Apply` only)

**Function:** `Start-PasswordExpiryReminder`

* Sends through Graph with retries (shared `Invoke-Plan`)
* Saves `user | expiry date | reminder` to the sent list

---

### 5. Report

* Everyone except `NotDue`

---

## Summary

```
Get: users + expiry date

Check: which reminder, already sent?

Plan: send the reminder

Send: send it, remember it

Report: sent / skipped / flagged
```
