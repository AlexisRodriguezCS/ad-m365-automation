function New-ChangeReport {
    [CmdletBinding()]
    param(
        # Snapshot run folders, e.g. Reports\Snapshots\Offboarding_20260919_101500
        [Parameter(Mandatory)]
        [string[]]$Path,

        [Parameter(Mandatory)]
        [string]$OutFile
    )

    # "CN=Jane Doe,OU=IT,DC=corp,DC=local" gives "Jane Doe" and "OU=IT,DC=corp,DC=local".
    # A comma in a name is written "\," so it isn't where the split happens
    function Get-DnName([string]$Dn) { if ($Dn -match '^CN=(.+?)(?<!\\),') { $Matches[1] -replace '\\,', ',' } else { $Dn } }
    function Get-DnParent([string]$Dn) { if ($Dn -match '^CN=.+?(?<!\\),(.+)$') { $Matches[1] } else { $Dn } }
    function Get-HtmlText([object]$Text) { [System.Net.WebUtility]::HtmlEncode("$Text") }

    # What to show for each person, in this order. Empty on both sides means the row is skipped,
    # so an on-prem client doesn't get empty Microsoft 365 rows
    $fields = [ordered]@{
        "Account on"            = { param($s) $s.AD.Enabled }
        "OU"                    = { param($s) if ($s.AD.DistinguishedName) { Get-DnParent $s.AD.DistinguishedName } }
        "Display name"          = { param($s) $s.AD.DisplayName }
        "Job title"             = { param($s) $s.AD.Title }
        "Department"            = { param($s) $s.AD.Department }
        "Manager"               = { param($s) if ($s.AD.Manager) { Get-DnName $s.AD.Manager } }
        "Description"           = { param($s) $s.AD.Description }
        "Microsoft 365 sign-in" = { param($s) $s.Entra.AccountEnabled }
        "Licenses"              = { param($s) if ($s.Entra) { @($s.Entra.LicenseSkuIds | Where-Object { $_ }).Count } }
        "Mailbox type"          = { param($s) $s.Mailbox.Type }
    }

    $sections = foreach ($folder in $Path | Sort-Object { (Split-Path $_ -Leaf) -replace '^.*_(\d{8}_\d{6})$', '$1' }) {
        # Offboarding_20260919_101500 gives "Offboarding" and the time it ran
        $leaf  = Split-Path $folder -Leaf
        $title = if ($leaf -match '^(.+)_(\d{8})_(\d{6})$') {
            "$($Matches[1]), " + [datetime]::ParseExact("$($Matches[2])$($Matches[3])", "yyyyMMddHHmmss", $null).ToString("yyyy-MM-dd HH:mm")
        } else { $leaf }

        # Pair each before with its after by CorrelationId. A name change saves the before under the
        # old username and the after under the new one, so the file name can't be used
        $people = [ordered]@{}
        foreach ($file in Get-ChildItem -Path $folder -Filter "*.json" | Sort-Object Name) {
            $snap = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $key  = if ($snap.CorrelationId) { $snap.CorrelationId } else { $snap.SamAccountName }
            if (-not $people.Contains($key)) { $people[$key] = @{} }
            $people[$key][$snap.Stage] = $snap
        }

        $cards = foreach ($p in $people.Values) {
            $before = $p.Before
            $after  = $p.After
            $who    = if ($before -and $after -and $before.SamAccountName -ne $after.SamAccountName) {
                "$($before.SamAccountName) (now $($after.SamAccountName))"
            } else { @($before, $after | Where-Object { $_ })[0].SamAccountName }

            $rows    = [System.Collections.Generic.List[string]]::new()
            $changed = 0

            foreach ($label in $fields.Keys) {
                $values = foreach ($s in $before, $after) {
                    $v = if ($s) { & $fields[$label] $s }
                    if ($v -is [bool]) { if ($v) { "Yes" } else { "No" } } else { "$v" }
                }
                if (-not ($values[0] -or $values[1])) { continue }
                $diff = $before -and $after -and $values[0] -ne $values[1]
                if ($diff) { $changed++ }
                $rows.Add("<tr$(if ($diff) { ' class="changed"' })><th>$label</th><td>$(Get-HtmlText $values[0])</td><td>$(Get-HtmlText $values[1])</td></tr>")
            }

            # Groups: only show what was taken away or added, plus how many stayed the same
            $was = @($before.AD.MemberOf | Where-Object { $_ } | ForEach-Object { Get-DnName $_ })
            $is  = @($after.AD.MemberOf  | Where-Object { $_ } | ForEach-Object { Get-DnName $_ })
            if ($before -and $after) {
                $removed = @($was | Where-Object { $_ -notin $is } | Sort-Object)
                $added   = @($is  | Where-Object { $_ -notin $was } | Sort-Object)
                $kept    = @($was | Where-Object { $_ -in $is }).Count
                $changed += $removed.Count + $added.Count
                $list = @(
                    $removed | ForEach-Object { "<span class=""removed"">- $(Get-HtmlText $_)</span>" }
                    $added   | ForEach-Object { "<span class=""added"">+ $(Get-HtmlText $_)</span>" }
                    if ($kept) { "<span class=""kept"">$kept kept the same</span>" }
                )
                if ($list) { $rows.Add("<tr$(if ($removed -or $added) { ' class="changed"' })><th>Groups</th><td colspan=""2"">$($list -join '<br>')</td></tr>") }
            }

            # Errors saved in the snapshot (for example Microsoft 365 wasn't reachable)
            foreach ($s in $before, $after | Where-Object { $_ }) {
                foreach ($e in "ADError", "EntraError", "MailboxError" | Where-Object { $s.$_ }) {
                    $rows.Add("<tr class=""error""><th>$($s.Stage): couldn't read</th><td colspan=""2"">$(Get-HtmlText $s.$e)</td></tr>")
                }
            }

            $summary = if (-not $after)      { "No after copy. The run stopped before it finished, so check this person by hand" }
                       elseif (-not $before) { "No before copy, so there's nothing to compare with" }
                       elseif ($changed)     { "$changed change(s)" }
                       else                  { "Nothing changed" }

            @"
<section class="person">
<h3>$(Get-HtmlText $who) <small>$(Get-HtmlText $summary)</small></h3>
<table><thead><tr><th></th><th>Before</th><th>After</th></tr></thead><tbody>
$($rows -join "`n")
</tbody></table>
</section>
"@
        }

        "<h2>$(Get-HtmlText $title)</h2>`n$($cards -join "`n")"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>What Changed</title>
<style>
:root { --bg: #fff; --fg: #1f2328; --muted: #656d76; --line: #d0d7de; --changed: #fff8c5; --removed: #cf222e; --added: #1a7f37; }
@media (prefers-color-scheme: dark) { :root { --bg: #0d1117; --fg: #e6edf3; --muted: #8d96a0; --line: #30363d; --changed: #3b2e00; --removed: #ff7b72; --added: #3fb950; } }
body { background: var(--bg); color: var(--fg); font: 15px/1.5 system-ui, sans-serif; max-width: 960px; margin: 0 auto; padding: 16px; }
h2 { border-bottom: 1px solid var(--line); padding-bottom: 4px; margin-top: 32px; }
h3 small { color: var(--muted); font-weight: normal; font-size: 14px; margin-left: 8px; }
table { border-collapse: collapse; width: 100%; table-layout: fixed; }
th, td { border: 1px solid var(--line); padding: 6px 8px; text-align: left; vertical-align: top; overflow-wrap: anywhere; }
tbody th { width: 180px; font-weight: 600; }
tr.changed td, tr.changed th { background: var(--changed); }
tr.error td, tr.error th { color: var(--removed); }
.removed { color: var(--removed); text-decoration: line-through; }
.added { color: var(--added); }
.kept, .note { color: var(--muted); }
</style>
</head>
<body>
<h1>What Changed</h1>
<p class="note">Made from the before and after copies on $(Get-Date -Format "yyyy-MM-dd HH:mm"). Yellow rows changed.</p>
$($sections -join "`n")
</body>
</html>
"@

    $html | Out-File -FilePath $OutFile -Encoding utf8
    Get-Item $OutFile
}
