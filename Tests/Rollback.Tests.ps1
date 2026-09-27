Describe "Restore from snapshot" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Rollback -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Rollback\Rollback.psm1" -Force

        $logFile  = "TestDrive:\rollback.log"
        $snapshot = Join-Path $TestDrive "jdoe_before.json"

        # Before offboarding: enabled, in IT OU, two groups, a title
        [ordered]@{
            Stage = "Before"; TakenAt = "2026-09-19T10:00:00"; SamAccountName = "jdoe"
            AD = [ordered]@{
                Enabled = $true; DistinguishedName = "CN=Jane Doe,OU=IT,DC=corp,DC=local"
                Title = "Engineer"; Department = "IT"; Manager = $null; Description = $null
                MemberOf = @("CN=GRP-AllStaff,DC=corp,DC=local", "CN=GRP_ROLE_IT_User,DC=corp,DC=local")
            }
            Entra   = @{ LicenseSkuIds = @("sku-e3") }
            Mailbox = @{ Type = "UserMailbox" }
        } | ConvertTo-Json -Depth 5 | Out-File $snapshot

        Mock Write-Log {} -ModuleName Rollback
    }

    BeforeEach {
        # After offboarding: disabled, in Disabled OU, no groups, one extra group added by mistake
        Mock Get-ADUser {
            [pscustomobject]@{
                Enabled = $false; DistinguishedName = "CN=Jane Doe,OU=Disabled,DC=corp,DC=local"
                Title = "Engineer"; Department = "IT"; Manager = $null; Description = "Offboarded 2026-09-19"
                MemberOf = @("CN=GRP-Leavers,DC=corp,DC=local")
            }
        } -ModuleName Rollback
        Mock Enable-ADAccount {} -ModuleName Rollback
        Mock Add-ADGroupMember {} -ModuleName Rollback
        Mock Remove-ADGroupMember {} -ModuleName Rollback
        Mock Move-ADObject {} -ModuleName Rollback
        Mock Set-ADUser {} -ModuleName Rollback
        Mock New-Report {} -ModuleName Rollback
    }

    It "plans only the difference, enable first and OU move last" {
        $user = New-RestorePlan -SnapshotFile $snapshot
        $actions = @($user.Plan | ForEach-Object { "$($_.Action):$($_.Target)" })

        $actions[0]  | Should -Be "EnableAccount:jdoe"
        $actions[-1] | Should -Be "MoveToOU:OU=IT,DC=corp,DC=local"
        $actions     | Should -Contain "AddToGroup:CN=GRP-AllStaff,DC=corp,DC=local"
        $actions     | Should -Contain "AddToGroup:CN=GRP_ROLE_IT_User,DC=corp,DC=local"
        $actions     | Should -Contain "RemoveFromGroup:CN=GRP-Leavers,DC=corp,DC=local"
        ($actions -join " ") | Should -Not -Match "SetAttribute:Title"   # unchanged
    }

    It "lists licenses and mailbox type for a human" {
        $user = New-RestorePlan -SnapshotFile $snapshot
        ($user.Manual -join " ") | Should -Match "sku-e3"
        ($user.Manual -join " ") | Should -Match "UserMailbox"
    }

    It "restores everything with -Apply" {
        $result = Invoke-RestoreFromSnapshot -SnapshotFile $snapshot -LogFile $logFile -Apply $true

        $result.Status | Should -Be "Restored"
        Should -Invoke Enable-ADAccount  -ModuleName Rollback -Times 1 -Exactly
        Should -Invoke Add-ADGroupMember -ModuleName Rollback -Times 2 -Exactly
        Should -Invoke Move-ADObject     -ModuleName Rollback -Times 1 -Exactly -ParameterFilter { $TargetPath -eq "OU=IT,DC=corp,DC=local" }
    }

    It "changes nothing in a preview" {
        $null = Invoke-RestoreFromSnapshot -SnapshotFile $snapshot -LogFile $logFile -Apply $false
        Should -Invoke Enable-ADAccount -ModuleName Rollback -Times 0 -Exactly
    }

    It "reports NoChange when the user already matches the snapshot" {
        Mock Get-ADUser {
            [pscustomobject]@{
                Enabled = $true; DistinguishedName = "CN=Jane Doe,OU=IT,DC=corp,DC=local"; Title = "Engineer"; Department = "IT"
                MemberOf = @("CN=GRP-AllStaff,DC=corp,DC=local", "CN=GRP_ROLE_IT_User,DC=corp,DC=local")
            }
        } -ModuleName Rollback

        (New-RestorePlan -SnapshotFile $snapshot).Status | Should -Be "NoChange"
    }
}

Describe "Change report" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Rollback -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Rollback\Rollback.psm1" -Force

        function Save-TestSnapshot($Folder, $Stage, $Sam, $CorrelationId, $AD) {
            $null = New-Item -ItemType Directory -Path $Folder -Force
            [ordered]@{ Stage = $Stage; SamAccountName = $Sam; CorrelationId = $CorrelationId; AD = $AD } |
                ConvertTo-Json -Depth 5 | Out-File (Join-Path $Folder "$($Sam)_$($Stage.ToLower()).json")
        }

        $offboarding = Join-Path $TestDrive "Offboarding_20260919_101500"
        Save-TestSnapshot $offboarding "Before" "jdoe" "id-1" ([ordered]@{
            Enabled = $true; DistinguishedName = "CN=Doe\, Jane,OU=IT,DC=corp,DC=local"; Title = "Engineer"
            Description = "<script>alert(1)</script>"
            MemberOf = @("CN=GRP-AllStaff,DC=corp,DC=local", "CN=GRP_ROLE_IT_User,DC=corp,DC=local")
        })
        Save-TestSnapshot $offboarding "After" "jdoe" "id-1" ([ordered]@{
            Enabled = $false; DistinguishedName = "CN=Doe\, Jane,OU=Disabled,DC=corp,DC=local"; Title = "Engineer"
            Description = "<script>alert(1)</script>"
            MemberOf = @("CN=GRP-AllStaff,DC=corp,DC=local", "CN=GRP-Leavers,DC=corp,DC=local")
        })
        # Stopped half way: no after copy
        Save-TestSnapshot $offboarding "Before" "bsmith" "id-2" ([ordered]@{ Enabled = $true })

        # A name change saves the before under the old username and the after under the new one
        $nameChange = Join-Path $TestDrive "NameChange_20260918_090000"
        Save-TestSnapshot $nameChange "Before" "jdoe" "id-3" ([ordered]@{ DisplayName = "Jane Doe" })
        Save-TestSnapshot $nameChange "After" "jsmith" "id-3" ([ordered]@{ DisplayName = "Jane Smith" })

        $out  = Join-Path $TestDrive "changes.html"
        $null = New-ChangeReport -Path $offboarding, $nameChange -OutFile $out
        $html = Get-Content $out -Raw
    }

    It "shows what changed and marks those rows" {
        $html | Should -Match '<tr class="changed"><th>Account on</th><td>Yes</td><td>No</td></tr>'
        $html | Should -Match '<tr class="changed"><th>OU</th><td>OU=IT,DC=corp,DC=local</td><td>OU=Disabled,DC=corp,DC=local</td></tr>'
        $html | Should -Match '<tr><th>Job title</th><td>Engineer</td><td>Engineer</td></tr>'
    }

    It "lists groups taken away and added, not every group" {
        $html | Should -Match 'class="removed">- GRP_ROLE_IT_User<'
        $html | Should -Match 'class="added">\+ GRP-Leavers<'
        $html | Should -Match '1 kept the same'
        $html | Should -Not -Match 'GRP-AllStaff'
        $html | Should -Match '4 change\(s\)'
    }

    It "pairs a renamed user by CorrelationId, and puts the runs in time order" {
        $html | Should -Match 'jdoe \(now jsmith\)'
        $html | Should -Match '<td>Jane Doe</td><td>Jane Smith</td>'
        $html.IndexOf("NameChange, 2026-09-18 09:00") | Should -BeLessThan $html.IndexOf("Offboarding, 2026-09-19 10:15")
    }

    It "says so when the run stopped before the after copy" {
        $html | Should -Match 'bsmith <small>No after copy'
    }

    It "doesn't let text from AD run as code in the page" {
        $html | Should -Not -Match '<script>'
        $html | Should -Match '&lt;script&gt;'
    }
}

Describe "Snapshot after a name change" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        . "$PSScriptRoot\..\Modules\Shared\Save-UserSnapshot.ps1"
        function Write-Log {}

        # The account only exists under the new username now
        Mock Get-ADUser { if ($Filter -like "*'jsmith'*") { [pscustomobject]@{ Enabled = $true; DisplayName = "Jane Smith"; MemberOf = @() } } }
        $user = [pscustomobject]@{
            CorrelationId = "abcdef12-0000"
            Identity      = [pscustomobject]@{ SamAccountName = "jdoe"; NewSamAccountName = "jsmith" }
        }
    }

    It "reads the account by its new username" {
        $file = Save-UserSnapshot -PipelineObject $user -Stage After -Folder $TestDrive
        Split-Path $file -Leaf | Should -Be "jsmith_after.json"
        (Get-Content $file -Raw | ConvertFrom-Json).AD.DisplayName | Should -Be "Jane Smith"
    }

    It "doesn't look for Microsoft 365 when there's no Entra account" {
        $file = Save-UserSnapshot -PipelineObject $user -Stage After -Folder $TestDrive
        (Get-Content $file -Raw | ConvertFrom-Json).PSObject.Properties.Name | Should -Not -Contain "EntraError"
    }
}
