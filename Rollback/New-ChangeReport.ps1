#Requires -Version 7.0
<#
    Turn the before and after copies into one easy to read web page: what changed for each person,
    with groups taken away and added. Good for a ticket, or for showing someone what a run did.
    Read-only. It only reads the JSON files.

    One run:   .\Rollback\New-ChangeReport.ps1 -Path .\Reports\Snapshots\Offboarding_20260919_101500
    Every run: .\Rollback\New-ChangeReport.ps1 -Path (Get-ChildItem .\Reports\Snapshots -Directory).FullName
#>
[CmdletBinding()]
param(
    # One or more snapshot run folders
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string[]]$Path,

    # Default: Changes_<date>.html next to the run folders, so the 90-day cleanup deletes it too
    [string]$OutFile
)

Import-Module "$PSScriptRoot\Rollback.psm1" -Force

if (-not $OutFile) {
    $OutFile = Join-Path (Split-Path (Resolve-Path $Path[0]) -Parent) "Changes_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
}

New-ChangeReport -Path (Resolve-Path $Path).Path -OutFile $OutFile
