# Inactive Accounts

Finds accounts nobody uses. Inactive employees get **disabled**, inactive guests get **removed**.
Unused accounts are an easy way in for attackers, and they still cost licenses.

How it works inside: [Docs/InactiveAccounts.md](Docs/InactiveAccounts.md)

---

## Steps

1. Get every enabled account and its last sign-in from Entra
2. Skip anyone on the exclude list (`ExcludeAccounts`) or the protected list (`ProtectedAccounts`), like break-glass, service and VIP accounts
3. Mark as inactive:
   * Employees: no sign-in for `MemberInactiveDays` (default 90)
   * Guests: no sign-in for `GuestInactiveDays` (default 90)
   * Never signed in: counted from the day the account was made, so new hires don't get caught
4. An unused account that **has an admin role** is never disabled by the script. It goes in the report as `AdminReview` for a person to check (an unused admin account is often a break-glass account, on purpose)
5. Plan: disable employees, remove guests
6. **Safety stop:** if more than `MaxPercentToDisable` (default 10%) of accounts look inactive, nothing gets changed. That usually means the sign-in data is missing
7. Save a **before** copy of each account
8. Disable (synced users in AD, cloud users in Entra) or remove the guest
9. Save an **after** copy
10. Write a report and a CSV to `Reports/`
11. Send an alert if there's anything to review

Steps 7-9 only run with `-Apply`.

---

## Usage

Review only (do this first, then weekly):
```powershell
.\InactiveAccounts\InactiveAccounts.ps1 -Client "ClientA"
```
Make the changes:
```powershell
.\InactiveAccounts\InactiveAccounts.ps1 -Client "ClientA" -Apply
```

---

## Notes

* Needs Entra ID P1 (for sign-in data) and the Graph permissions `User.ReadWrite.All` and `AuditLog.Read.All`.
* Disabled accounts can be turned back on. Removed guests can be restored for 30 days.
