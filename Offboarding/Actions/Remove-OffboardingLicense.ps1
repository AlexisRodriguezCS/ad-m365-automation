function Remove-OffboardingLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Get currently assigned licenses, and how each one was given
    $user = Get-MgUser -UserId $Identity.EntraUPN `
                       -Property "assignedLicenses,licenseAssignmentStates" `
                       -ErrorAction Stop

    # A license that comes from a group can't be removed from the user (Graph refuses the whole call).
    # It goes away by itself when they leave the group, which offboarding does before this step
    $states  = @($user.LicenseAssignmentStates | Where-Object { $_.SkuId })
    $skuIds  = @($states | Where-Object { -not $_.AssignedByGroup } | ForEach-Object SkuId | Select-Object -Unique)
    $byGroup = @($states | Where-Object { $_.AssignedByGroup } | ForEach-Object SkuId | Select-Object -Unique | Where-Object { $_ -notin $skuIds })

    if ($skuIds.Count -eq 0) {
        if ($byGroup) { return "NoDirectLicenses ($($byGroup.Count) from groups, removed with the group)" }
        return "NoLicenses"
    }

    # Remove all licenses
    try {
        $null = Set-MgUserLicense -UserId $Identity.EntraUPN `
            -AddLicenses @() `
            -RemoveLicenses $skuIds `
            -ErrorAction Stop
    }
    catch {
        throw "License removal failed: $($_.Exception.Message)"
    }

    return "Licenses removed"
}
