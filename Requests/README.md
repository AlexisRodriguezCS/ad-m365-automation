# HR Requests (Self-Service)

HR doesn't run scripts. They fill in a SharePoint list, and the scripts do the rest.

---

## For HR: how to use it

1. Open the **IT Requests** list in SharePoint (or the Microsoft Lists or Teams app)
2. Click **+ New**
3. Pick the **Request type** and fill in the boxes:

| Request type | Fill in |
|---|---|
| **New hire** | First name, Last name, Employee ID, Job title, Department, Role, Manager name, Start date |
| **Role change** | Username, Job title, Department, Role, Manager username |
| **Leaver** | Username, Manager email (they get the mailbox and OneDrive) |
| **Update info** | Username, plus only the boxes that change (phone, title, office...) |
| **Unlock account** | Username |
| **Reset password** | Username (IT gets the temp password and gives it to them. It's never shown in the list) |
| **Group access** | Username, Group, Add or remove (only groups IT has allowed for requests) |

4. **When**: leave it empty for as soon as possible, or pick a date and time (like a leaver's last day at 5 PM)
5. Save. The request waits for approval.

The **Status** column tells you what's going on:

| Status | Meaning |
|---|---|
| New | Waiting for approval |
| Approved | Approved. It'll run at the "When" time (or within 15 minutes) |
| Processing | Running now |
| Done | Finished. **Result** says what was done |
| Needs attention | Something's wrong. **Result** says what (like "no account found with username jsmyth"). IT gets an alert too |
| Rejected | Not approved |

**Urgent leaver?** Leave "When" empty. Or call IT, they can run it right away.

---

## For IT: setup

1. Create the list (one time):
   ```powershell
   .\Requests\Setup\New-RequestList.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/HR" -Departments Finance,IT,Sales,HR,Marketing
   ```
2. Permissions: HR gets Contribute, approvers get Edit.
3. Approval: either an approver changes **Status** to *Approved*, or add a Power Automate flow
   (*When an item is created*, then *Start and wait for an approval*, then set Status to Approved or Rejected).
4. Add `Config/Clients/<Client>/Requests.json` (see the main README).
5. Schedule the queue every 15 minutes:
   ```powershell
   .\Requests\Invoke-RequestQueue.ps1 -Client "ClientA" -Apply
   ```

---

## Steps (each run)

1. Read the list and keep the **Approved** items (plus any stuck on **Processing** for over an hour, from a run that crashed)
2. **Make sure the approval is real**: SharePoint's version history has to show the change to Approved was made by someone in `Approvers`, and not by the person who made the request. If not: *Needs attention*
3. Skip items whose **When** is still in the future (shows "Scheduled: will run ...")
4. Set **Processing** (so two runs can't do the same request)
5. Run the matching script: onboarding, mover, offboarding, user attributes, or the help desk actions (unlock, reset password, group access)
6. Temp passwords get emailed to IT, and are **never** written to the list
7. Set **Done** or **Needs attention**, with a result in plain English
8. Alert IT if anything needs attention

If the request type is one the scripts don't know (renamed in the list, or a typo), it's marked *Needs attention* and says which type, instead of failing without a word.

---

## Usage

**Preview**: reads the list and shows what would happen. Nothing changes and the list isn't updated:
```powershell
.\Requests\Invoke-RequestQueue.ps1 -Client "ClientA"
```

**Process**: the scheduled run:
```powershell
.\Requests\Invoke-RequestQueue.ps1 -Client "ClientA" -Apply
```

Runs every 15 minutes as a scheduled task ([`Setup/Register-ScheduledTasks.ps1`](../Setup/Register-ScheduledTasks.ps1)). Safe to run by hand any time: each request is marked *Processing* first, so two runs can't do the same one.
