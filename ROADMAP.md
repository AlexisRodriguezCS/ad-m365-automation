# Roadmap

What a business actually needs from account automation: **stay secure, stop wasting money, pass audits, and save help desk time.**

---

## Done

**Employee lifecycle (Joiner, Mover, Leaver)**
- [x] **Onboarding**: new hire gets an account, groups, email lists, a license and a random temp password
- [x] **Role change (mover)**: new title, department and manager, old role access swapped for the new one
- [x] **User attributes**: HR or IT update details (title, phone, office...), only what changed
- [x] **Name change**: marriage or legal name change. New name, optional new username and email, old address kept as an alias
- [x] **Offboarding**: lock out, remove access, give mailbox and OneDrive to the manager, free up licenses
- [x] **One person or bulk**: every people script takes parameters or a CSV

**Security**
- [x] **Inactive accounts**: disable unused employees, remove old guests, with a safety stop
- [x] **MFA gaps**: no MFA, admins using SMS only
- [x] **Admin audit**: who has roles, too many Global Admins, guests with admin
- [x] **Mail forwarding audit**: forwarding and inbox rules sending mail outside
- [x] **Expiring app secrets and certificates**

**Save money**
- [x] **License report**: bought vs assigned, cost per department
- [x] **Wasted licenses**: unused, on disabled accounts, on idle accounts

**Audits and compliance**
- [x] **Access review**: one sheet per manager, Keep or Remove
- [x] **Offboarding check**: leavers still enabled, still in groups, or still licensed
- [x] **Before/after copies**: every change saved as JSON

**Help desk**
- [x] **Password expiry emails**: 14, 7 and 1 days before, never sent twice

**Platform**
- [x] **HR self-service**: SharePoint list with approval, results written back in plain English
- [x] **Scheduled or urgent**: requests run at a set time (like a leaver's last day at 5 PM) or right away
- [x] **Alerts**: Teams and/or email when anything needs attention
- [x] **Scheduled tasks**: one setup script, runs as a gMSA (no saved password)
- [x] **Circuit breaker**: a bulk run stops if several people in a row fail, instead of failing everyone
- [x] **Logs you can search**: one file per day plus a `.jsonl` copy, with a run ID and person ID on every line, kept 365 days

**Lab**
- [x] **Home lab**: Windows Server 2025 domain controller on Hyper-V, built by script ([Lab](Lab/README.md)). Onboarding, mover, name change, offboarding, rollback and AD Structure have all been run against it for real
- [x] **AD Structure**: builds a client's OUs and groups from a JSON file, and sends new users and computers to real OUs so Group Policy reaches them
- [x] **Demo**: one command runs a made-up employee through hire, promotion, name change, leaving and undo, and saves everything it did
- [x] **On-prem only clients**: `"Environment": "OnPrem"` skips every Microsoft 365 step
- [x] **Domain controller health**: one DC, FSMO roles, backups, services, disks, SYSVOL, clock, time source and replication (`Audits -Check ADHealth`)
- [x] **GPO backup and change detection**: every GPO backed up (restorable with `Import-GPO`) when something changed, and added, edited, deleted, unlinked, empty or out-of-sync GPOs get flagged (`Audits -Check GroupPolicy`)

---

## Next up

### Foundation
- [ ] **Connect the lab to Microsoft 365**: add a test tenant and Entra Connect, so the cloud steps can be run for real too
- [ ] **Screenshots**: add real screenshots of the demo and the lab to the READMEs
- [ ] **Cloud only clients**: create users straight in Entra ID (`New-MgUser`) when there's no on-prem AD, so one `Environment` setting covers cloud, hybrid and on-prem

### 1. Gaps job postings ask for
- [x] **Intune device cleanup**: retire devices not seen in 90 days, delete the records after 180 (`StaleDevices`)
  - *Why:* Intune is in almost every Microsoft 365 admin job posting.
- [x] **Leaver device retire**: offboarding retires the leaver's phones and laptops (company data removed, personal data left alone)
  - *Why:* otherwise company data leaves on personal phones.
- [x] **Conditional Access backup and change detection**: every policy backed up to JSON, and added, changed or deleted policies get flagged (`Audits -Check ConditionalAccess`)
  - *Why:* a changed CA policy is a common cause of both breaches and outages, and CA is in most job postings.
- [x] **Temporary Access Pass onboarding**: optional one-time sign-in code for day one (`UseTemporaryAccessPass`)
  - *Why:* passwordless is the modern standard, and there's no password to leak.

### 2. Security operations
- [x] **Compromised account response**: save evidence first, then disable, reset, sign out, and remove forwarding and bad inbox rules (`IncidentResponse`)
  - *Why:* the "someone got phished" steps, done in seconds instead of from memory.
- [x] **Risky users**: Entra ID Protection at-risk and compromised accounts, with next steps (`Audits -Check RiskyUsers`)
- [x] **Privileged access review**: admins with permanent roles vs PIM-eligible (`Audits -Check PrivilegedAccess`)
- [x] **Email security check**: SPF, DKIM and DMARC for every domain (`Audits -Check EmailSecurity`)
  - *Why:* stops people faking your email address. Also listed in job postings.

### 3. Groups and access cleanup
- [x] **Empty or ownerless groups and Teams**: flagged for cleanup or a new owner (`Audits -Check Groups`)
- [x] **Shared mailbox access report**: FullAccess and SendAs, disabled people who still have access, sign-in not blocked (`Audits -Check SharedMailboxes`)
- [x] **External sharing report**: sites where "anyone with the link" works, and guests nobody has reviewed (`Audits -Check ExternalSharing`)

### 4. Help desk
- [x] **User activity timeline**: sign-ins, password resets, lockouts (and which device), MFA and CA failures, with a plain English summary (`UserActivity`)
- [x] **Account unlock and password reset** through the request list (temp password goes to IT only, admins refused)
- [x] **Group membership requests** through the request list, approved, only for allowed groups (`RequestableGroups`)
- [x] **Mailbox size warnings** before mailboxes fill up (`MailboxQuota`)

### Later
- [x] **Undo from a saved copy**: put back the account, groups, attributes and OU from a before-copy (`Rollback`)
- [x] **Offboarding: hide from the address book**
- [x] **Offboarding: remove from Teams and Microsoft 365 groups** (the manager takes over teams the leaver was the only owner of)
- [ ] **Before/after HTML report**: an easy to read page made from the before/after copies, for demos and tickets
- [ ] **PowerShell Universal portal**: buttons to run the scripts, written only in PowerShell

---

## Last: demo portal

A small web page, hosted on the lab PC, that shows what the scripts do as they run:

- Pick a request (new hire, role change, leaver, update info) and watch each step run
- Each change shown as it happens, like **Lisa Taylor, Title: Accountant to Finance Manager**
- Offboarding shows the user **before** and **after** side by side (from the saved copies): enabled to disabled, 5 groups to 0, E3 license to none, mailbox to shared
- It reads the same reports and saved copies the scripts already make, so it doesn't change how anything works

Good for demos and interviews. The real way HR asks for changes stays the SharePoint list, since sign-in, permissions and approvals come free with Microsoft 365.
