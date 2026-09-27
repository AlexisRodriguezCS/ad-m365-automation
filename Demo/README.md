# Demo

One command takes a made-up employee through their whole time at a company, on the lab, and saves everything it did in one folder.

```powershell
# Preview, changes nothing
.\Demo\Invoke-Demo.ps1 -Client Lab

# Run it
.\Demo\Invoke-Demo.ps1 -Client Lab -Apply
```

**Lab only.** It deletes and recreates the demo account every run, so you can run it twice in front of someone without resetting anything.

---

## The story

| | Step | What it shows |
|---|---|---|
| 1 | **Hired** | Account created in the right department, with the right access and a temp password |
| 2 | **Promoted** | Old role access removed, new access added, moved to the new department |
| 3 | **Name change** | Got married: new name, new username, and **mail sent to the old address still arrives** |
| 4 | **Leaving** | Locked out, access removed, moved to the Disabled OU |
| 5 | **Undo** | Put back exactly how the before copy says they were |

After each step it reads the account back from Active Directory and prints it. So it shows what's really in AD, not what the script says it did:

```
 3. NAME CHANGE
      Name     : Jordan Brooks   (jordanbrooks)
      Job      : Support Technician, IT
      Enabled  : True
      Where    : OU=IT,OU=Employees,OU=Users,OU=Identity
      Access   : GRP_ROLE_IT_Helpdesk, GRP-AllStaff

 4. LEAVING
      Name     : Jordan Brooks   (jordanbrooks)
      Enabled  : False
      Where    : OU=Disabled,OU=Users,OU=Identity
      Access   : none
```

Anything that changed since the last step is marked `<- changed`.

---

## What you get

`Demo\Output\Demo_<date>\`

```
demo.txt                      everything that was printed
OnboardingReport_*.txt        one report per step
MoverReport_*.txt
NameChangeReport_*.txt
OffboardingReport_*.txt
RestoreReport_*.txt
changes.html                  what changed at each step, as one easy to read page
Snapshots\
    Mover_<date>\             the account before and after each step, as JSON
    NameChange_<date>\
    Offboarding_<date>\
```

Good for screenshots, and for showing someone what a run leaves behind.

---

## Requirements

* The lab domain from [Lab](../Lab/README.md), with the OUs from [AD Structure](../ADStructure/README.md)
* A client config with `"Environment": "OnPrem"`. With a full hybrid config, the cloud steps run too
* PowerShell 7 and the ActiveDirectory module, on the domain controller or a PC with RSAT
