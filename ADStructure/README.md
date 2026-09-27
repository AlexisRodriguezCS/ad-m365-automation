# AD Structure

Builds a client's Active Directory setup from a JSON file: the OUs, the groups, and where new users and computers get created.

---

## Why you need it

A new domain comes with almost nothing:

| What you get | Type |
|---|---|
| `Domain Controllers` | OU |
| `Users` | **Container** |
| `Computers` | **Container** |
| `Builtin`, `System`, `ForeignSecurityPrincipals`... | Containers |

**You can't link Group Policy to a container.** Windows puts new accounts in `CN=Users` and new domain-joined PCs in `CN=Computers`, and those are the two places your policies can't reach. So every new PC misses your policies until someone moves it.

This script builds real OUs, then makes new users and computers go into them.

---

## Steps

1. Read the structure file (the client's own, or the sample in `Data/`)
2. Create the OUs, parents first, and skip any that already exist
3. Create the groups in the OUs the file says
4. Make new **users** and new **computers** go into real OUs (`redirusr` / `redircmp`)
5. Print a summary and write a log

Dry run by default: it only shows what it *would* create. Add `-Apply` to build it. Safe to run again, anything that already exists is left alone.

---

## Usage

```powershell
# Preview
.\ADStructure\New-ADStructure.ps1 -Client "ClientA"

# Build it
.\ADStructure\New-ADStructure.ps1 -Client "ClientA" -Apply

# Build the OUs but don't change where new users and computers go
.\ADStructure\New-ADStructure.ps1 -Client "ClientA" -Apply -SkipRedirect
```

It uses `Config\Clients\<Client>\structure.json` if there is one, otherwise [`Data\structure.json`](Data/structure.json). Use `-Path` to pick a different file.

---

## The default layout

```
OU=Identity
+-- OU=Users
|   +-- OU=Employees        <- new accounts go here (one OU per department)
|   +-- OU=Contractors
|   +-- OU=ServiceAccounts
|   \-- OU=Disabled         <- offboarding moves leavers here
+-- OU=Computers
|   +-- OU=Workstations     <- new domain-joined PCs go here
|   +-- OU=Laptops
|   +-- OU=Kiosks
|   \-- OU=Disabled         <- retired hardware
+-- OU=Servers
|   +-- OU=Application
|   +-- OU=Database
|   \-- OU=Infrastructure
\-- OU=Groups
    +-- OU=Role             <- GRP_ROLE_* (the only groups the scripts change)
    +-- OU=Security
    \-- OU=Distribution
```

To change it, edit the JSON. The tree is built exactly as written, as deep as you want.

```json
{
    "ProtectFromDeletion": true,
    "OUs": [
        { "Name": "Identity", "Children": [
            { "Name": "Users", "Children": [ { "Name": "Employees" } ] }
        ]}
    ],
    "Groups": [
        { "Name": "GRP-AllStaff", "Path": "OU=Security,OU=Groups,OU=Identity" }
    ],
    "Redirect": {
        "Users": "OU=Employees,OU=Users,OU=Identity",
        "Computers": "OU=Workstations,OU=Computers,OU=Identity"
    }
}
```

A group's `Path` and the `Redirect` values leave out the domain part. The script adds it (`DC=contoso,DC=local`), so the same file works for any client.

---

## Notes

* **`ProtectFromDeletion`** turns on delete protection for every OU, so nobody can delete a whole department by mistake in ADUC. **It's on unless you set it to `false`.** Turn it off for a lab you rebuild a lot.
* **`redirusr` / `redircmp`** come with AD DS and there's no PowerShell version, so the script runs them directly. They change a setting on the domain itself. You can check it after with `(Get-ADDomain).UsersContainer`.
* The OU names match the other scripts: onboarding puts a new hire in `OU=<Department>,<DefaultOU>`, offboarding moves leavers to `DisabledOU`, and a role change only touches `GRP_ROLE_*` groups.
* It needs Domain Admin. That's fine, because a person runs it by hand once per client. See [SECURITY.md](../SECURITY.md).
