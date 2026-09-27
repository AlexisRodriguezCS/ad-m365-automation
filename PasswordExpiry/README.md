# Password Expiry Reminders

Emails people before their password expires, so they change it in time instead of calling the help desk because they're locked out.

How it works inside: [Docs/PasswordExpiry.md](Docs/PasswordExpiry.md)

---

## Steps

1. Get every enabled AD user whose password can expire
2. Work out how many days are left
3. Pick the reminder: 14, 7 or 1 day (you can change these in `NotifyDays`)
4. Skip it if that reminder was already sent (no repeat emails, even if it runs many times a day)
5. Flag anyone who needs a reminder but has no email address
6. Send the email from the IT mailbox
7. Remember what was sent
8. Write a report to `Reports/`

Steps 6-7 only run with `-Apply`.

If a day gets missed (say the server was down), the next run still sends the right reminder.

---

## Usage

See who would get an email:
```powershell
.\PasswordExpiry\PasswordExpiry.ps1 -Client "ClientA"
```
Send:
```powershell
.\PasswordExpiry\PasswordExpiry.ps1 -Client "ClientA" -Apply
```

Schedule it once a day.

---

## Email

The subject and body come from the config, so you can change the wording without touching the code:

```json
"EmailSubject": "Your password expires in {Days}",
"EmailBody": "Hi {Name},\n\nYour password expires {Date} ({Days}).\nChange it here: {ResetUrl}\n\nIT Help Desk"
```

Needs the Graph permission `Mail.Send` for `SenderMailbox` (limit it to that one mailbox with an application access policy).
