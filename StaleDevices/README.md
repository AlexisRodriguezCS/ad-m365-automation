# Stale Devices (Intune)

Cleans up laptops and phones that stopped checking in to Intune.
Lost, replaced or forgotten devices still have company data on them, and they mess up compliance reports.

How it works inside: [Docs/StaleDevices.md](Docs/StaleDevices.md)

---

## Steps

1. Get every Intune device and when it last checked in
2. Skip devices on the exclude list (kiosks, spares)
3. Mark as stale: no check-in for `RetireAfterDays` (default 90)
4. Plan for each stale device:
   * **Retire**: removes company data, apps and email the next time it checks in (personal data is left alone). Never sent twice
   * **Delete record**: no check-in for `DeleteAfterDays` (default 180). The device is gone, so remove it from Intune
5. **Safety stop:** if more than `MaxPercentToChange` (default 20%) of devices would change, nothing runs
6. Run the plan with retries
7. Write a report and a CSV (device, owner, serial, last check-in) to `Reports/`
8. Send an alert if there's anything to review or anything failed

Step 6 only runs with `-Apply`.

---

## Usage

Review only:
```powershell
.\StaleDevices\StaleDevices.ps1 -Client "ClientA"
```
Make the changes:
```powershell
.\StaleDevices\StaleDevices.ps1 -Client "ClientA" -Apply
```

---

## Config (`StaleDevices.json`)

```json
{
    "RetireAfterDays": 90,
    "DeleteAfterDays": 180,
    "MaxPercentToChange": 20,
    "ExcludeDevices": ["LOBBY-KIOSK", "CONF-ROOM-1"],
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000"
}
```

Graph permissions: `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`.
