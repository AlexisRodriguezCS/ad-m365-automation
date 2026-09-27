Describe "New-ADStructure" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        $script:adStructure = "$PSScriptRoot\..\ADStructure\New-ADStructure.ps1"

        # CI has no ActiveDirectory module, so pretend it's installed
        Mock Get-Module { [pscustomobject]@{ Name = "ActiveDirectory" } } -ParameterFilter { $Name -eq "ActiveDirectory" }
        Mock Import-Module {} -ParameterFilter { $Name -eq "ActiveDirectory" }
        Mock Get-ADDomain { [pscustomobject]@{ DistinguishedName = "DC=lab,DC=local" } }

        function New-StructureFile($Data) {
            $path = Join-Path $TestDrive "structure.json"
            $Data | ConvertTo-Json -Depth 10 | Set-Content $path
            $path
        }
    }

    BeforeEach {
        Mock Get-ADOrganizationalUnit { $null }
        Mock New-ADOrganizationalUnit {}
        Mock Get-ADGroup { $null }
        Mock New-ADGroup {}
    }

    It "doesn't break on a name with an apostrophe" {
        $path = New-StructureFile @{ OUs = @(@{ Name = "O'Brien Consulting" }) }

        $null = & $adStructure -Client "Test" -Path $path -SkipRedirect -Apply 6>$null

        # AD filters need the quote doubled. Unescaped, or with \', it's a syntax error on a real DC.
        Should -Invoke Get-ADOrganizationalUnit -Times 1 -Exactly -ParameterFilter {
            $Filter -eq "DistinguishedName -eq 'OU=O''Brien Consulting,DC=lab,DC=local'"
        }
        Should -Invoke New-ADOrganizationalUnit -Times 1 -Exactly -ParameterFilter { $Name -eq "O'Brien Consulting" }
    }

    It "doubles the quote in a group name too" {
        $path = New-StructureFile @{ OUs = @(); Groups = @(@{ Name = "GRP-O'Brien"; Path = "OU=Groups" }) }

        $null = & $adStructure -Client "Test" -Path $path -SkipRedirect -Apply 6>$null

        Should -Invoke Get-ADGroup -Times 1 -Exactly -ParameterFilter { $Filter -eq "Name -eq 'GRP-O''Brien'" }
        Should -Invoke New-ADGroup -Times 1 -Exactly
    }

    It "protects OUs from deletion when the file doesn't say" {
        $path = New-StructureFile @{ OUs = @(@{ Name = "Staff" }) }

        $null = & $adStructure -Client "Test" -Path $path -SkipRedirect -Apply 6>$null

        Should -Invoke New-ADOrganizationalUnit -Times 1 -Exactly -ParameterFilter { $ProtectedFromAccidentalDeletion -eq $true }
    }

    It "leaves protection off when the file turns it off" {
        $path = New-StructureFile @{ ProtectFromDeletion = $false; OUs = @(@{ Name = "Staff" }) }

        $null = & $adStructure -Client "Test" -Path $path -SkipRedirect -Apply 6>$null

        Should -Invoke New-ADOrganizationalUnit -Times 1 -Exactly -ParameterFilter { $ProtectedFromAccidentalDeletion -eq $false }
    }

    It "creates nothing in a dry run" {
        $path = New-StructureFile @{
            OUs    = @(@{ Name = "Staff"; Children = @(@{ Name = "IT" }) })
            Groups = @(@{ Name = "GRP-AllStaff"; Path = "OU=Staff" })
        }

        $null = & $adStructure -Client "Test" -Path $path -SkipRedirect 6>$null

        Should -Invoke New-ADOrganizationalUnit -Times 0 -Exactly
        Should -Invoke New-ADGroup -Times 0 -Exactly
    }

    It "leaves alone what already exists, so it's safe to run again" {
        Mock Get-ADOrganizationalUnit { [pscustomobject]@{ Name = "Staff" } }
        Mock Get-ADGroup { [pscustomobject]@{ Name = "GRP-AllStaff" } }
        $path = New-StructureFile @{
            OUs    = @(@{ Name = "Staff" })
            Groups = @(@{ Name = "GRP-AllStaff"; Path = "OU=Staff" })
        }

        $null = & $adStructure -Client "Test" -Path $path -SkipRedirect -Apply 6>$null

        Should -Invoke New-ADOrganizationalUnit -Times 0 -Exactly
        Should -Invoke New-ADGroup -Times 0 -Exactly
    }

    It "says it failed when redirusr isn't there, instead of saying it worked" {
        # On a real domain controller redirusr exists, and running this would change where new
        # users get created. So this only runs on machines that don't have it, like CI.
        if (Get-Command redirusr -ErrorAction SilentlyContinue) {
            Set-ItResult -Skipped -Because "redirusr exists here, so this is a domain controller"
        }

        Mock Get-ADOrganizationalUnit { [pscustomobject]@{ Name = "Employees" } }
        $path = New-StructureFile @{ OUs = @(); Redirect = @{ Users = "OU=Employees" } }

        $output = & $adStructure -Client "Test" -Path $path -Apply 6>&1 | Out-String

        $output | Should -Match "FAILED redirusr: not found"
        $output | Should -Not -Match "now land in"
    }
}
