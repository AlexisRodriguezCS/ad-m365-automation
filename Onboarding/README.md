# Onboarding

Creates new users from an HR CSV: AD account, groups, email lists and a Microsoft 365 license.

How it works inside: [Docs/Onboarding.md](Docs/Onboarding.md)

---

## Steps

1. Read the CSV
2. Clean up names, titles and departments (extra spaces, capital letters)
3. Check the required fields (skip bad rows)
4. Pick email lists, AD groups and a license based on department, title and role
5. Build the plan
6. Make the username, UPN, display name and OU, and find the manager in AD
7. Create the AD user with a random temp password, job title, department, office, company and manager (skip if it already exists)
8. Start an Entra Connect delta sync
9. Wait for the user to show up in Entra
    * Optional: create a **Temporary Access Pass** (a one-time sign-in code for day one, good from 8:00 on the start date) when `UseTemporaryAccessPass` is on
10. Add them to AD groups
11. Give them a Microsoft 365 license (this creates the mailbox)
12. Add them to email lists (waits for the mailbox to exist)
13. Write a report to `Reports/`
14. Show the temp passwords on screen, once

Steps 7-12 and 14 only run with `-Apply`. Temp passwords and access passes are never saved in logs or reports, and temp passwords have to be changed at first sign-in.

---

## Usage

**One person**
```powershell
.\Onboarding\Onboarding.ps1 -Client "ClientA" -FirstName Alex -LastName Johnson -Title "Accountant" -Department Finance -Role Accountant -Manager "Mary Smith"
```

**Many people**
```powershell
.\Onboarding\Onboarding.ps1 -Client "ClientA" -Path .\Onboarding\Data\test.csv
```

These are dry runs (no changes). Add `-Apply` to make the changes.

---

## CSV

| FirstName | LastName | Title | Manager | Location | Department | Role | EmploymentType | StartDate |
|-----------|----------|-------|---------|----------|------------|------|----------------|-----------|
| Alex | Johnson | Systems Administrator | Mary Smith | New York | IT | Admin | Regular Full-Time | 2026-02-26 |

**Manager** can be a full name or a username. If nobody in AD matches (or two people have the same name), the account still gets created and the report says the manager wasn't set.

**Capital letters:** if HR types something all lowercase or ALL CAPS, it gets fixed ("john smith" becomes "John Smith"). If it's mixed, it's kept exactly as typed, so O'Brien, McDonald and "IT Manager" stay right.

---

## Setup

One-time lab setup (department OUs, role groups, email lists):
```powershell
.\Onboarding\Setup\Initialize-OnboardingEnvironment.ps1 -Client "ClientA" -AdminUPN "admin@contoso.onmicrosoft.com"
```
