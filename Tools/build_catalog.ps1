# Builds Stratagem's bundled BiS quest snapshot from a local Naowh Forever install.
# The addon does not need this at runtime. Run it again when that install's
# BiS quest list or spec rankings change, then replace Data\Quests.lua and
# Data\ItemSpecs.lua.
#
#   powershell -File Tools\build_catalog.ps1
#   powershell -File Tools\build_catalog.ps1 -Source "D:\WoW\World of Warcraft\_classic_beta_\Interface\AddOns"

param(
    [string]$Source = "D:\WoW\World of Warcraft\_classic_beta_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"
$journal = Join-Path $Source "NaowhForever_DungeonJournal\Data\BiSQuests.lua"
$bis = Join-Path $Source "NaowhForever_BiS\BiS\Data\BiS.lua"
if (-not (Test-Path $journal)) { throw "Missing $journal" }
if (-not (Test-Path $bis)) { throw "Missing $bis" }

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "Data"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Quests that are done inside a dungeon. Used only to group the dungeon category.
$dungeonOf = @{
    5724 = "Ragefire Chasm"; 5725 = "Ragefire Chasm"; 5730 = "Ragefire Chasm"
    962 = "Wailing Caverns"; 1486 = "Wailing Caverns"; 1487 = "Wailing Caverns"
    914 = "Wailing Caverns"; 3369 = "Wailing Caverns"; 3370 = "Wailing Caverns"
    214 = "The Deadmines"; 166 = "The Deadmines"; 2040 = "The Deadmines"
    1098 = "Shadowfang Keep"; 1014 = "Shadowfang Keep"; 1013 = "Shadowfang Keep"
    971 = "Blackfathom Deeps"; 1200 = "Blackfathom Deeps"; 6561 = "Blackfathom Deeps"
    6565 = "Blackfathom Deeps"; 1199 = "Blackfathom Deeps"; 1275 = "Blackfathom Deeps"
    96403 = "The Hall of Thanes"; 96394 = "The Hall of Thanes"
    96393 = "The Hall of Thanes"; 96395 = "The Hall of Thanes"
    92401 = "Ruins of Lordaeron"; 92422 = "Ruins of Lordaeron"
    92421 = "Ruins of Lordaeron"; 95216 = "Ruins of Lordaeron"
    97290 = "Ruins of Lordaeron"; 95250 = "Ruins of Lordaeron"
    95195 = "Ruins of Lordaeron"; 95161 = "Ruins of Lordaeron"
}

function Escape-Lua([string]$s) {
    if ($null -eq $s) { return "" }
    return ($s -replace '\\', '\\' -replace '"', '\"')
}

$section = "none"
$quests = New-Object System.Collections.Generic.List[object]
$rewards = @{}
$choices = @{}
$zones = @{}
$skipped = @()

Get-Content -Path $journal -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^J\.BiSQuestRewards') { $section = "rewards"; return }
    if ($line -match '^J\.BiSQuestChoices') { $section = "choices"; return }
    if ($line -match '^J\.BiSQuestZones') { $section = "zones"; return }

    if ($section -eq "none" -and $line -match '^\{') { $section = "quests" }

    if ($section -eq "quests" -and $line -match '^\{') {
        $questRe = '^\{ (\d+), "([^"]*)", (\d+), "([HAB])", (true|false|"pre"), "([^"]*)"(.*)\},?$'
        if ($line -match $questRe) {
            $id = [int]$Matches[1]
            $name = $Matches[2]
            $level = [int]$Matches[3]
            $side = $Matches[4]
            $where = $Matches[6]
            $rest = $Matches[7]
            $map = $null; $x = $null; $y = $null
            if ($rest -match '^,\s*(\d+),\s*([0-9.]+),\s*([0-9.]+)(.*)$') {
                $map = [int]$Matches[1]
                $x = $Matches[2]
                $y = $Matches[3]
                $rest = $Matches[4]
            }
            $class = $null; $races = $null
            $classMatch = [regex]::Match($rest, 'class\s*=\s*"([A-Z]+)"')
            if ($classMatch.Success) { $class = $classMatch.Groups[1].Value }
            $raceMatch = [regex]::Match($rest, 'races\s*=\s*(\d+)')
            if ($raceMatch.Success) { $races = $raceMatch.Groups[1].Value }
            $quests.Add([pscustomobject]@{
                id = $id; name = $name; level = $level; side = $side; where = $where
                map = $map; x = $x; y = $y; class = $class; races = $races
            }) | Out-Null
        } else {
            $skipped += $line
        }
    } elseif ($section -eq "rewards" -and $line -match '^\[(\d+)\]\s*=\s*\{([^}]*)\}') {
        $rewardQuest = [int]$Matches[1]
        $rewardBody = $Matches[2]
        $ids = @()
        foreach ($n in ($rewardBody -split ',')) {
            $t = $n.Trim()
            if ($t -match '^\d+$') { $ids += [int]$t }
        }
        $rewards[$rewardQuest] = $ids
    } elseif ($section -eq "choices" -and $line -match '^\[(\d+)\]\s*=\s*true') {
        $choices[[int]$Matches[1]] = $true
    } elseif ($section -eq "zones" -and $line -match '^\[(\d+)\]\s*=\s*"([^"]+)"') {
        $zones[[int]$Matches[1]] = $Matches[2]
    }
}

if ($skipped.Count -gt 0) {
    Write-Warning ("Skipped {0} quest line(s):" -f $skipped.Count)
    $skipped | Select-Object -First 8 | ForEach-Object { Write-Warning $_ }
}

$rewardIds = @{}
foreach ($list in $rewards.Values) { foreach ($id in $list) { $rewardIds[$id] = $true } }

# itemID -> specKey -> best rank + slot. Only items that a BiS quest actually awards.
$itemSpecs = @{}
$specCounts = @{}
$specKey = $null
Get-Content -Path $bis -Encoding UTF8 | ForEach-Object {
    if ($_ -match 'key = "([^"]+)"') { $specKey = $Matches[1] }
    if ($specKey -and $_ -match '^\s*\[(\d+)\] = \{([^}]*)\}') {
        $slot = [int]$Matches[1]
        $rank = 0
        foreach ($n in ($Matches[2] -split ',')) {
            $t = $n.Trim()
            if ($t -notmatch '^\d+$') { continue }
            $rank++
            $itemID = [int]$t
            if (-not $rewardIds.ContainsKey($itemID)) { continue }
            if (-not $itemSpecs.ContainsKey($itemID)) { $itemSpecs[$itemID] = @{} }
            $prev = $itemSpecs[$itemID][$specKey]
            if (-not $prev -or $rank -lt $prev.rank) {
                $itemSpecs[$itemID][$specKey] = @{ rank = $rank; slot = $slot }
            }
            if (-not $specCounts.ContainsKey($specKey)) { $specCounts[$specKey] = 0 }
            $specCounts[$specKey]++
        }
    }
}

$inv = [Globalization.CultureInfo]::InvariantCulture
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- Bundled snapshot of quests that reward a best-in-slot item.")
[void]$sb.AppendLine("-- Generated by Tools\build_catalog.ps1 from NaowhForever_DungeonJournal Data\BiSQuests.lua.")
[void]$sb.AppendLine("-- Live journal data replaces this while Naowh Forever is enabled. Safe to regenerate.")
[void]$sb.AppendLine("local _, SG = ...")
[void]$sb.AppendLine("if type(SG) ~= `"table`" then")
[void]$sb.AppendLine("    SG = _G.Stratagem or {}")
[void]$sb.AppendLine("    _G.Stratagem = SG")
[void]$sb.AppendLine("end")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("SG.BundledQuests = {")

$ordered = $quests | Sort-Object level, id
foreach ($q in $ordered) {
    $zone = $zones[$q.id]
    if (-not $zone -and $q.where -match '^(.+?) - ') { $zone = $Matches[1] }
    if ($zone -eq "Where it starts is not known yet") { $zone = $null }
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add(("id = {0}" -f $q.id))
    $parts.Add(("name = `"{0}`"" -f (Escape-Lua $q.name)))
    $parts.Add(("level = {0}" -f $q.level))
    $parts.Add(("side = `"{0}`"" -f $q.side))
    if ($zone) { $parts.Add(("zone = `"{0}`"" -f (Escape-Lua $zone))) }
    if ($q.map) { $parts.Add(("map = {0}" -f $q.map)) }
    if ($q.x) { $parts.Add(("x = {0}" -f $q.x)) }
    if ($q.y) { $parts.Add(("y = {0}" -f $q.y)) }
    $parts.Add(("where = `"{0}`"" -f (Escape-Lua $q.where)))
    if ($q.class) { $parts.Add(("class = `"{0}`"" -f $q.class)) }
    if ($q.races) { $parts.Add(("races = {0}" -f $q.races)) }
    $rew = $rewards[$q.id]
    if ($rew -and $rew.Count -gt 0) {
        $parts.Add(("rewards = {{ {0} }}" -f ($rew -join ", ")))
    }
    if ($choices.ContainsKey($q.id)) { $parts.Add("choice = true") }
    $dung = $dungeonOf[[int]$q.id]
    if ($dung) { $parts.Add(("dungeon = `"{0}`"" -f (Escape-Lua $dung))) }
    [void]$sb.AppendLine(("    {{ {0} }}," -f ($parts -join ", ")))
}
[void]$sb.AppendLine("}")
[void]$sb.AppendLine("")
[void]$sb.AppendLine(("SG.BundledQuestCount = {0}" -f $ordered.Count))

$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $outDir "Quests.lua"), $sb.ToString(), $utf8)

$ib = New-Object System.Text.StringBuilder
[void]$ib.AppendLine("-- Which bundled quest rewards are ranked for each spec, and how high.")
[void]$ib.AppendLine("-- Generated by Tools\build_catalog.ps1 from NaowhForever_BiS Data\BiS.lua.")
[void]$ib.AppendLine("-- Rank 1 is that spec's best item in the slot. Live BiS data replaces this in game.")
[void]$ib.AppendLine("local _, SG = ...")
[void]$ib.AppendLine("if type(SG) ~= `"table`" then")
[void]$ib.AppendLine("    SG = _G.Stratagem or {}")
[void]$ib.AppendLine("    _G.Stratagem = SG")
[void]$ib.AppendLine("end")
[void]$ib.AppendLine("")
[void]$ib.AppendLine("SG.BundledItems = {")
foreach ($itemID in ($itemSpecs.Keys | Sort-Object)) {
    $bits = New-Object System.Collections.Generic.List[string]
    foreach ($key in ($itemSpecs[$itemID].Keys | Sort-Object)) {
        $row = $itemSpecs[$itemID][$key]
        $bits.Add(('["{0}"] = {{ rank = {1}, slot = {2} }}' -f $key, $row.rank, $row.slot))
    }
    [void]$ib.AppendLine(("    [{0}] = {{ {1} }}," -f $itemID, ($bits -join ", ")))
}
[void]$ib.AppendLine("}")
[IO.File]::WriteAllText((Join-Path $outDir "ItemSpecs.lua"), $ib.ToString(), $utf8)

$withReward = 0
foreach ($q in $ordered) { if ($rewards.ContainsKey($q.id)) { $withReward++ } }
"Quests: $($ordered.Count)  with rewards: $withReward  choice: $($choices.Count)  zones: $($zones.Count)"
"Reward items: $($rewardIds.Count)  ranked on a spec: $($itemSpecs.Count)  specs touched: $($specCounts.Count)"
if ($ordered.Count -lt 100) { throw "Quest parse looks short ($($ordered.Count)). Check BiSQuests.lua format." }
$sample = $ordered | Where-Object { $_.id -eq 855 }
if (-not $sample) { throw "Centaur Bracers (855) missing from snapshot." }
if (-not $rewards.ContainsKey(855)) { throw "Quest 855 has no rewards." }
$fire = $ordered | Where-Object { $_.id -eq 94411 }
if ($fire.map -ne 2521 -or $fire.races -ne "32") { throw "94411 parse failed map=$($fire.map) races=$($fire.races) where=$($fire.where)" }
"Sample 855 zone=$($zones[855]) rewards=$($rewards[855] -join ',')"
"Sample 94411 map=$($fire.map) x=$($fire.x) races=$($fire.races)"
