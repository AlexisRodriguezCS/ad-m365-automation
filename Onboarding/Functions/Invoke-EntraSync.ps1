function Invoke-EntraSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    try {
        # Trigger delta sync on the AD Connect server. Errors on the other server (module missing, a sync
        # already running) don't stop anything unless told to, so this would say "triggered" when it wasn't
        $null = Invoke-Command -ComputerName $Config.ADConnectServer -ErrorAction Stop -ScriptBlock {
            $ErrorActionPreference = "Stop"
            Import-Module ADSync
            Start-ADSyncSyncCycle -PolicyType Delta
        }
        Write-Log -Message "SyncToEntra : Delta sync triggered" -Level "INFO" -LogFile $LogFile
    }
    catch {
        throw "Failed to trigger AD sync: $($_.Exception.Message)"
    }
}