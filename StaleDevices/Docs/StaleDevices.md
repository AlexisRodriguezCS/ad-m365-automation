## Stale Devices - How It Works

### Overview

Cleans up Intune devices that stopped checking in. Retire first, then delete the record once the device is clearly gone. Only reports until you add `-Apply`.

---

## Order

### 1. Get the data

**Function:** `Get-DeviceData`

* Every Intune device from Graph, with `lastSyncDateTime`, owner, OS, serial, compliance and `managementState`
* One pipeline object per device (same shape as the people scripts, so the shared report and retry engine work as-is)

---

### 2. Check

**Function:** `Test-StaleDevice`

* Devices listed in `ExcludeDevices`: `Excluded` (kiosks, conference room PCs, spares in a drawer)
* No check-in for `RetireAfterDays` (default 90): `Stale`
* Never checked in at all: `Stale`, and treated as the oldest possible
* Everything else: `Active`

---

### 3. Plan

**Function:** `New-StaleDevicePlan`

* `DaysSinceSync` at or over `DeleteAfterDays` (default 180): **DeleteRecord**. The device is gone, so remove it from Intune
* Otherwise: **Retire**. Company data, apps and email are removed the next time it checks in. Personal data is left alone
* A device that already shows `retirePending` doesn't get a second retire

---

### 4. Safety stop

**Function:** `Invoke-StaleDeviceCleanup`

* If more than `MaxPercentToChange` (default 20%) of all devices would change, nothing runs
* A number that high almost always means the sync data is wrong, not that every laptop disappeared
* The devices still show up in the report, marked `Failed`, with the reason

---

### 5. Make the changes

**Actions:** `Invoke-DeviceRetire`, `Remove-DeviceRecord`

* Run through the shared `Invoke-Plan` retry engine (3 tries, waiting longer each time)
* Ends as `Retired`, `Deleted` or `Failed`

---

### 6. Report

* `Reports/StaleDevicesReport_<date>.txt`, problems at the top
* `Reports/StaleDevices_<date>.csv`, the full list for Excel
* An alert if anything failed, and another on a review-only run when there's something to approve

---

## Config

| Key | Default | Meaning |
|---|---|---|
| `RetireAfterDays` | 90 | No check-in for this long: retire |
| `DeleteAfterDays` | 180 | No check-in for this long: delete the record |
| `MaxPercentToChange` | 20 | Safety stop |
| `ExcludeDevices` | - | Device names that are never touched |

---

## Permissions

Graph application permissions: `DeviceManagementManagedDevices.ReadWrite.All` and `DeviceManagementManagedDevices.PrivilegedOperations.All` (to retire).
