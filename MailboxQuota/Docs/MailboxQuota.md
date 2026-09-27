## Mailbox Quota - How It Works

### Overview

Warns people before their mailbox is full, so IT hears about it before "I can't send email". Runs every day, and each warning level is sent at most once a month.

---

## Order

### 1. Get the data

**Function:** `Get-MailboxQuotaData`

* Every user mailbox from Exchange Online, with its send limit
* `ConvertTo-Bytes` reads Exchange's size text (`"49.5 GB (53,150,220,288 bytes)"`) and turns it into a number of bytes
* Mailboxes with no limit are skipped, since they can't fill up
* Works out the percent used for each mailbox

> It makes one call per mailbox. That's fine for a few thousand mailboxes. For more than that, switch to a scheduled usage report.

---

### 2. Check

**Function:** `Test-MailboxQuota`

* Finds the highest level in `WarnAtPercent` the mailbox has reached. For example 92% full gets the 90% warning
* Under every level: `Ok`, and it doesn't show up in the report
* Each sent warning is remembered as `mailbox | level | year-month`, so a person gets one warning per level per month even though the script runs every day

---

### 3. Send

**Action:** `Send-MailboxQuotaWarning`

* The subject and body come from the config, with `{Name}`, `{Percent}`, `{Used}` and `{Quota}` filled in exactly as-is (a name with `$1` in it stays as typed)
* Sent from `SenderMailbox` through Graph, and not saved to Sent Items
* Tried up to 3 times through the shared retry engine

---

### 4. Remember

* Sent warnings are saved in `Logs/SentWarnings_<Client>.json`
* Anything older than about 2 months is dropped when the file loads, so it doesn't keep growing
* In a dry run nothing is sent and nothing is saved

---

### 5. Report

* `Reports/MailboxQuotaReport_<date>.txt`, only mailboxes over a level
* Alert and exit code 1 if any email failed to send

---

## Config

| Key | Example | Meaning |
|---|---|---|
| `WarnAtPercent` | `[80, 90, 95]` | Levels that send a warning |
| `SenderMailbox` | `it-helpdesk@contoso.com` | Who the email comes from |
| `EmailSubject` | `Your mailbox is {Percent}% full` | Subject template |
| `EmailBody` | `Hi {Name}, {Used} of {Quota} GB used.` | Body template |

---

## Permissions

Exchange Online `Exchange.ManageAsApp` with *View-Only Recipients* (read mailbox sizes) and Graph `Mail.Send` (send as the sender mailbox).
