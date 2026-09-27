function Get-ADHealthAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [string]$LogFile,
        # Injectable for tests
        [datetime]$Now = (Get-Date)
    )

    $minFreePercent = if ($Config.MinFreeDiskPercent)  { $Config.MinFreeDiskPercent }  else { 15 }
    $maxBackupDays  = if ($Config.MaxBackupAgeDays)    { $Config.MaxBackupAgeDays }    else { 7 }
    $maxSkewSeconds = if ($Config.MaxTimeSkewSeconds)  { $Config.MaxTimeSkewSeconds }  else { 60 }
    $maxReplHours   = if ($Config.MaxReplicationHours) { $Config.MaxReplicationHours } else { 24 }

    # A domain controller doesn't work without these
    $requiredServices = "NTDS", "DNS", "Netlogon", "Kdc", "W32Time", "DFSR", "ADWS"

    $domain = Get-ADDomain -ErrorAction Stop
    $forest = Get-ADForest -ErrorAction Stop
    $dcs    = @(Get-ADDomainController -Filter * -ErrorAction Stop)

    # With one DC there's no second copy of AD. If it dies, nobody signs in until it's restored
    $single = $dcs.Count -lt 2
    New-AuditFinding -Check "ADHealth" -Name $domain.DNSRoot -Detail "$($dcs.Count) domain controller(s)" -Flagged $single `
                     -Reason $(if ($single) { "Only one domain controller. If it fails, nobody can sign in until it's restored from backup" })

    # A role held by a DC that no longer exists has to be seized
    $roles = [ordered]@{
        "PDC Emulator"          = $domain.PDCEmulator
        "RID Master"            = $domain.RIDMaster
        "Infrastructure Master" = $domain.InfrastructureMaster
        "Schema Master"         = $forest.SchemaMaster
        "Domain Naming Master"  = $forest.DomainNamingMaster
    }
    foreach ($role in $roles.Keys) {
        $gone = $roles[$role] -notin $dcs.HostName
        New-AuditFinding -Check "ADHealth" -Name $role -Detail "Held by $($roles[$role])" -Flagged $gone `
                         -Reason $(if ($gone) { "That server isn't a domain controller any more, so the role has to be seized" })
    }

    # Backups. A system state backup updates dSASignature. AD writes version 1 when the domain is
    # created and every backup adds one, so version 1 means it was never backed up (same as repadmin /showbackup)
    $signature = Get-ADReplicationAttributeMetadata -Object $domain.DistinguishedName -Server $domain.PDCEmulator -Properties dSASignature -ErrorAction Stop
    if ($signature.Version -le 1) {
        New-AuditFinding -Check "ADHealth" -Name "AD backup" -Detail "Never backed up" -Flagged $true `
                         -Reason "AD has never been backed up. Without a backup, a deleted OU or a dead DC can't be recovered"
    }
    else {
        $lastBackup = $signature.LastOriginatingChangeTime
        $backupDays = [int]($Now - $lastBackup).TotalDays
        $oldBackup  = $backupDays -gt $maxBackupDays
        New-AuditFinding -Check "ADHealth" -Name "AD backup" -Detail "Last backup $($lastBackup.ToString('yyyy-MM-dd')) ($backupDays days ago)" -Flagged $oldBackup `
                         -Reason $(if ($oldBackup) { "No AD backup in the last $maxBackupDays days. Without one, a deleted OU or a dead DC can't be recovered" })
    }

    foreach ($dc in $dcs) {
        $name = $dc.HostName

        # Everything below comes over one CIM session, so a DC that's down is one finding, not a pile of errors
        try {
            $cim = New-CimSession -ComputerName $name -ErrorAction Stop
        }
        catch {
            New-AuditFinding -Check "ADHealth" -Name $name -Detail "Not reachable" -Flagged $true -Reason "Can't connect to it: $($_.Exception.Message)"
            continue
        }

        try {
            # Services
            $services = @(Get-CimInstance -CimSession $cim -ClassName Win32_Service -ErrorAction Stop)
            $down = foreach ($s in $requiredServices) {
                $found = $services | Where-Object Name -eq $s
                if (-not $found) { "$s (not installed)" } elseif ($found.State -ne "Running") { "$s ($($found.State))" }
            }
            New-AuditFinding -Check "ADHealth" -Name $name -Detail "Services: $(if ($down) { $down -join ', ' } else { 'all running' })" `
                             -Flagged ([bool]$down) -Reason $(if ($down) { "Not running: $($down -join ', ')" })

            # Disks
            foreach ($disk in Get-CimInstance -CimSession $cim -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop) {
                if (-not $disk.Size) { continue }
                $percent = [math]::Round($disk.FreeSpace / $disk.Size * 100)
                $low     = $percent -lt $minFreePercent
                New-AuditFinding -Check "ADHealth" -Name $name `
                                 -Detail "Disk $($disk.DeviceID) $([math]::Round($disk.FreeSpace / 1GB, 1)) GB free of $([math]::Round($disk.Size / 1GB)) GB ($percent%)" `
                                 -Flagged $low -Reason $(if ($low) { "Under $minFreePercent% free. A full disk stops AD from writing its database and logs" })
            }

            # SYSVOL and NETLOGON. Without them, Group Policy and logon scripts don't reach anyone
            $shares  = @(Get-CimInstance -CimSession $cim -ClassName Win32_Share -ErrorAction Stop).Name
            $missing = @("SYSVOL", "NETLOGON" | Where-Object { $_ -notin $shares })
            New-AuditFinding -Check "ADHealth" -Name $name -Detail "Shares: $(if ($missing) { "missing $($missing -join ', ')" } else { 'SYSVOL and NETLOGON shared' })" `
                             -Flagged ([bool]$missing) -Reason $(if ($missing) { "Missing $($missing -join ' and '). Group Policy won't apply from this DC" })

            # Clock. Kerberos stops working past 5 minutes, so warn well before that
            $clock = (Get-CimInstance -CimSession $cim -ClassName Win32_OperatingSystem -ErrorAction Stop).LocalDateTime
            $skew  = [int][math]::Abs(((Get-Date) - $clock).TotalSeconds)
            $off   = $skew -gt $maxSkewSeconds
            New-AuditFinding -Check "ADHealth" -Name $name -Detail "Clock is $skew seconds off from this machine" -Flagged $off `
                             -Reason $(if ($off) { "More than $maxSkewSeconds seconds off. Past 5 minutes, sign-ins fail" })
        }
        catch {
            New-AuditFinding -Check "ADHealth" -Name $name -Detail "Check failed" -Flagged $true -Reason $_.Exception.Message
        }
        finally {
            Remove-CimSession $cim -ErrorAction SilentlyContinue
        }

        # Replication. Failures right now, and partners that haven't replicated in a while
        foreach ($failure in @(Get-ADReplicationFailure -Target $name -ErrorAction SilentlyContinue | Where-Object FailureCount -gt 0)) {
            New-AuditFinding -Check "ADHealth" -Name $name -Detail "Replication from $($failure.Partner) failing since $($failure.FirstFailureTime)" `
                             -Flagged $true -Reason "$($failure.FailureCount) failures: $($failure.LastError)"
        }
        foreach ($partner in @(Get-ADReplicationPartnerMetadata -Target $name -ErrorAction SilentlyContinue)) {
            $hours = [int]($Now - $partner.LastReplicationSuccess).TotalHours
            $stale = $hours -gt $maxReplHours
            New-AuditFinding -Check "ADHealth" -Name $name -Detail "Last replicated from $($partner.Partner) $hours hours ago" -Flagged $stale `
                             -Reason $(if ($stale) { "No replication in over $maxReplHours hours. Changes on one DC aren't reaching the others" })
        }
    }

    # The PDC is where the whole domain gets its time, so it should get it from an outside time server
    $source = "$(& w32tm /query /computer:$($domain.PDCEmulator) /source 2>&1)".Trim()
    $reason = if ($source -match "error occurred|denied|not found") { "Couldn't read the time source: $source" }
              elseif ($source -match "Local CMOS Clock|Free-running") { "The PDC is using its own clock. Point it at an outside time server (w32tm /config /manualpeerlist), or the whole domain drifts" }
              elseif ($source -match "VM IC Time") { "The PDC takes its time from the Hyper-V host. Microsoft recommends a virtual PDC use an outside time server (w32tm /config /manualpeerlist) instead" }
    New-AuditFinding -Check "ADHealth" -Name "Time source" -Detail "PDC ($($domain.PDCEmulator)) gets time from: $source" -Flagged ([bool]$reason) -Reason $reason
}
