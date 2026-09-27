## User Attributes - How It Works

### Overview

Changes AD attributes safely: checked first, only what's different, one logged action per value, and a before and after copy.

---

## Order

### 1. Request

**Function:** `New-UserAttributesRequest`

* Turns a CSV row or the parameters into a pipeline object
* Only keeps the attributes that were given a value

---

### 2. Check

**Function:** `Test-UserAttributesData`

* The username is valid
* At least one attribute
* Only allowed attributes, nothing empty, 128 characters max
* Manager has to be a username

---

### 3. Find the user

**Function:** `Get-UserAttributesIdentity`

* Finds the user with all the attributes this script manages
* Turns the manager's username into the DN AD needs
* `NotFound` or `Invalid` if either one doesn't exist

---

### 4. Plan

**Function:** `New-UserAttributesPlan`, which uses `Get-UserAttributeChanges`

* One `SetAttribute` for each value that's different (capital letters count)
* If nothing is different: `NoChange`

---

### 5. Make the changes (`-Apply` only)

**Function:** `Start-UserAttributesUpdate`

* Before and after copy of the account
* Runs the plan with retries (shared `Invoke-Plan`)

---

### 6. Report

**Function:** `New-Report` (shared)

---

## Summary

```
Request: one person or a CSV

Check: are the values ok

Find: current values in AD

Plan: only what's different

Change: set each value

Report: old value -> new value, pass or fail
```
