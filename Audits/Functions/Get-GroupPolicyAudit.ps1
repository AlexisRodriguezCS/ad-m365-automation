function Get-GroupPolicyAudit {
    [CmdletBinding()]
    param(
        # Where backups are kept (not under Reports/, so the 90-day cleanup doesn't delete them)
        [Parameter(Mandatory)]
        [string]$BackupFolder,

        [string]$LogFile
    )

    # Windows creates these two with every domain, with the same IDs everywhere
    $defaults = @{
        "31b2f340-016d-11d2-945f-00c04fb984f9" = "Default Domain Policy"
        "6ac1786c-016f-11d2-945f-00c04fb984f9" = "Default Domain Controllers Policy"
    }

    $domain = Get-ADDomain -ErrorAction Stop

    # Read GPOs straight from AD, which is where Get-GPO gets them anyway. In PowerShell 7, Get-GPO runs
    # through Windows PowerShell behind the scenes and comes back without its version numbers
    $gpos = @(Get-ADObject -SearchBase "CN=Policies,CN=System,$($domain.DistinguishedName)" -Filter "objectClass -eq 'groupPolicyContainer'" `
                           -Properties displayName, versionNumber, flags, gPCFileSysPath, whenChanged -ErrorAction Stop)
    $statusNames = "AllSettingsEnabled", "UserSettingsDisabled", "ComputerSettingsDisabled", "AllSettingsDisabled"

    # Where each GPO is linked. gPLink holds "[LDAP://cn={guid},...;option]" and option 1 or 3 means the link
    # is turned off. The GUID's capitals don't always match the GPO's, so compare them as GUIDs
    $links = @{}
    foreach ($target in Get-ADObject -LDAPFilter "(gPLink=*)" -SearchBase $domain.DistinguishedName -Properties gPLink -ErrorAction Stop) {
        foreach ($m in [regex]::Matches("$($target.gPLink)", '\{([0-9a-fA-F-]{36})\}[^;\]]*;(\d)')) {
            if ([int]$m.Groups[2].Value -band 1) { continue }
            $id = ([guid]$m.Groups[1].Value).ToString()
            if (-not $links.ContainsKey($id)) { $links[$id] = [System.Collections.Generic.List[string]]::new() }
            $links[$id].Add($target.DistinguishedName)
        }
    }

    # The version numbers go up every time a GPO is edited, so they show what changed. One number holds
    # both: the user version is the top 16 bits, the computer version the bottom 16. The SYSVOL copy
    # of the same number is in GPT.INI
    $current = @(foreach ($gpo in $gpos) {
        $id     = ([guid]$gpo.Name).ToString()
        $ini    = Get-Content -Path (Join-Path $gpo.gPCFileSysPath "GPT.INI") -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*Version\s*=' }
        $sysvol = if ($ini) { [int](($ini | Select-Object -First 1) -replace '^\s*Version\s*=\s*') } else { -1 }
        [pscustomobject]@{
            Id              = $id
            Name            = $gpo.displayName
            Status          = $statusNames[[int]$gpo.flags]
            UserVersion     = [int]$gpo.versionNumber -shr 16
            ComputerVersion = [int]$gpo.versionNumber -band 0xFFFF
            # -1 means GPT.INI couldn't be read, which is its own problem
            UserSysvol      = if ($sysvol -ge 0) { $sysvol -shr 16 } else { -1 }
            ComputerSysvol  = if ($sysvol -ge 0) { $sysvol -band 0xFFFF } else { -1 }
            Modified        = ([datetime]$gpo.whenChanged).ToString("s")
            LinkedTo        = if ($links.ContainsKey($id)) { @($links[$id]) } else { @() }
        }
    })

    # The last backup, to compare against
    $null = New-Item -ItemType Directory -Path $BackupFolder -Force
    $last = Get-ChildItem -Path $BackupFolder -Directory | Where-Object { Test-Path (Join-Path $_.FullName "gpos.json") } |
            Sort-Object Name | Select-Object -Last 1
    $previous = @{}
    if ($last) {
        foreach ($p in (Get-Content (Join-Path $last.FullName "gpos.json") -Raw | ConvertFrom-Json)) { $previous[$p.Id] = $p }
    }

    $anyChange = $false

    foreach ($gpo in $current) {
        $problems = [System.Collections.Generic.List[string]]::new()
        $was      = $previous[$gpo.Id]

        if ($last -and -not $was) {
            $problems.Add("New since the last backup")
            $anyChange = $true
        }
        elseif ($was) {
            $what = @(
                if ($was.UserVersion -ne $gpo.UserVersion -or $was.ComputerVersion -ne $gpo.ComputerVersion) { "settings edited" }
                if ($was.Status -ne $gpo.Status) { "status $($was.Status) -> $($gpo.Status)" }
                # Each side needs its own brackets. Without them PowerShell runs -join and -ne left to right,
                # joins the True/False into text, and that text is never empty, so it always said "changed"
                if (((@($was.LinkedTo) | Sort-Object) -join ";") -ne ((@($gpo.LinkedTo) | Sort-Object) -join ";")) { "links changed" }
                if ($was.Name -ne $gpo.Name) { "renamed from '$($was.Name)'" }
            )
            if ($what) {
                $problems.Add("Changed since the last backup ($($what -join ', ')). Previous version: $($last.Name)")
                $anyChange = $true
            }
        }

        if (-not $gpo.LinkedTo.Count) { $problems.Add("Not linked anywhere, so it does nothing. Link it or delete it") }
        if ($gpo.UserVersion -eq 0 -and $gpo.ComputerVersion -eq 0) { $problems.Add("Empty, nothing is set in it") }
        if ($gpo.Status -eq "AllSettingsDisabled") { $problems.Add("Every setting in it is turned off") }

        # Settings live in two places: AD and the SYSVOL share. If the versions don't match, SYSVOL
        # probably isn't replicating, and computers can get old settings or none
        if ($gpo.UserSysvol -lt 0) {
            $problems.Add("Can't read its GPT.INI in SYSVOL. Its files may be missing, so computers can't apply it")
        }
        elseif ($gpo.UserVersion -ne $gpo.UserSysvol -or $gpo.ComputerVersion -ne $gpo.ComputerSysvol) {
            $problems.Add("AD and SYSVOL versions don't match (AD user $($gpo.UserVersion)/computer $($gpo.ComputerVersion), SYSVOL user $($gpo.UserSysvol)/computer $($gpo.ComputerSysvol)). SYSVOL may not be replicating")
        }

        $linked = if ($gpo.LinkedTo.Count) { "linked to $($gpo.LinkedTo.Count) place(s)" } else { "not linked" }
        New-AuditFinding -Check "GroupPolicy" -Name $gpo.Name `
                         -Detail "$($gpo.Status) | $linked | version user $($gpo.UserVersion), computer $($gpo.ComputerVersion) | modified $($gpo.Modified)$(if (-not $last) { ' | first backup' })" `
                         -Flagged ([bool]$problems.Count) -Reason ($problems -join ". ")
    }

    # GPOs that are gone. The last backup still has them
    foreach ($id in @($previous.Keys | Where-Object { $_ -notin $current.Id })) {
        $anyChange = $true
        $name = $previous[$id].Name
        New-AuditFinding -Check "GroupPolicy" -Name $name -Detail "Last seen in $($last.Name)" -Flagged $true `
                         -Reason "Deleted since the last backup. To bring it back: Import-GPO -Path '$($last.FullName)' -BackupGpoName '$name' -TargetName '$name' -CreateIfNeeded (then link it again)"
    }

    # The two default policies should always exist
    foreach ($id in $defaults.Keys | Where-Object { $_ -notin $current.Id }) {
        New-AuditFinding -Check "GroupPolicy" -Name $defaults[$id] -Detail "Missing" -Flagged $true `
                         -Reason "It's gone. Restore it from a backup, or rebuild it with dcgpofix"
    }

    # Only take a new backup when something changed, so the folder doesn't fill up with copies
    if (-not $last -or $anyChange) {
        $folder = Join-Path $BackupFolder (Get-Date -Format "yyyyMMdd_HHmmss")
        $null = New-Item -ItemType Directory -Path $folder -Force
        $null = Backup-GPO -All -Path $folder -ErrorAction Stop
        ConvertTo-Json -InputObject $current -Depth 5 | Out-File -FilePath (Join-Path $folder "gpos.json") -Encoding utf8
    }
}
