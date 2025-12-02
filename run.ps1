#Requires -Version 5.1
#Requires -RunAsAdministrator

# Ensure UTF-8 output to avoid garbled text in Windows PowerShell 5.1
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = [Console]::OutputEncoding
}
catch {}

function Find-SogouInstallation {
    # Return an array of validated SogouInput install directories
    $candidatePaths = @()

    # Registry hints (InstallPath should contain SogouInput)
    $registryPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\SogouInput',
        'HKLM:\SOFTWARE\SogouInput',
        'HKCU:\SOFTWARE\SogouInput'
    )

    foreach ($regPath in $registryPaths) {
        try {
            if (Test-Path $regPath) {
                $prop = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                foreach ($name in @('InstallPath', 'Path', 'InstallDir')) {
                    if ($prop.$name) { $candidatePaths += [string]$prop.$name }
                }
            }
        }
        catch {}
    }

    # Common install locations
    $commonPaths = @(
        'C:\Program Files (x86)\SogouInput',
        'C:\Program Files\SogouInput',
        'D:\Program Files (x86)\SogouInput',
        'D:\Program Files\SogouInput',
        'E:\Program Files (x86)\SogouInput',
        'E:\Program Files\SogouInput'
    )
    $candidatePaths += $commonPaths

    # From running processes
    try {
        $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'sogou' }
        foreach ($p in $procs) {
            try {
                $dir = Split-Path $p.MainModule.FileName -Parent
                if ($dir) { $candidatePaths += $dir }
            }
            catch {}
        }
    }
    catch {}

    # Normalize, dedupe and strictly validate: folder name must be SogouInput
    $valid = @()
    foreach ($path in ($candidatePaths | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)) {
        try {
            if (-not (Test-Path $path)) { continue }
            $leaf = Split-Path $path -Leaf
            if ($leaf -ne 'SogouInput') { continue }

            # Must contain at least one executable with name matching sogou*
            $hasExe = Get-ChildItem -Path $path -Recurse -Include *.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^sogou|^sg' }
            if ($hasExe) { $valid += $path }
        }
        catch {}
    }

    return ($valid | Sort-Object -Unique)
}

function Disable-Network {
    param (
        [string[]] $folderNames
    )

    Remove-NetFirewallRule -DisplayName 'Sogou Pinyin Service' -ErrorAction Ignore

    $groupName = 'SogouInput Block'

    # 统计本脚本使用的分组中，原来就有多少条规则（用于之后计算“新增加了多少条”）
    $beforeRules = 0
    try {
        $beforeRules = (Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue | Measure-Object).Count
    }
    catch {}

    # Build a set of existing program paths that already have rules in this group,
    # so we only add missing ones (idempotent behavior).
    $existingPrograms = @{}
    try {
        $appFilters = Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue |
        Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue

        foreach ($af in $appFilters) {
            if ($af.Program) {
                $key = $af.Program.ToLower()
                $existingPrograms[$key] = $true
            }
        }
    }
    catch {}

    $total = 0
    foreach ($folderName in $folderNames) {
        $displayName = "blocked $folderName via script"

        Write-Host "Adding rules for: $folderName"
        $count = 0
        Get-ChildItem -Path $folderName -Recurse *.exe -ErrorAction SilentlyContinue | ForEach-Object -Process {
            $programPath = $_.FullName
            $programKey = $programPath.ToLower()

            if ($existingPrograms.ContainsKey($programKey)) {
                # Rule(s) for this program already exist in our group; skip creating duplicates.
                return
            }

            New-NetFirewallRule `
                -DisplayName $displayName `
                -Group $groupName `
                -Direction Inbound `
                -Program $programPath `
                -Action Block `
            | Out-Null

            New-NetFirewallRule `
                -DisplayName $displayName `
                -Group $groupName `
                -Direction Outbound `
                -Program $programPath `
                -Action Block `
            | Out-Null

            $existingPrograms[$programKey] = $true
            $count += 2
        }
        Write-Host "Added $count rules"
        $total += $count
    }

    # 统计当前分组下总共有多少条规则，并计算本次新加数量
    $afterRules = $beforeRules
    try {
        $afterRules = (Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue | Measure-Object).Count
    }
    catch {}

    $newRules = $afterRules - $beforeRules

    Write-Host "Successfully added $total rules in total (per-folder sum)"
    Write-Host "New firewall rules created in this run: $newRules" -ForegroundColor Green
    Write-Host "Total firewall rules in group '$groupName' now: $afterRules" -ForegroundColor Green
}

# Main
$paths = Find-SogouInstallation

# 额外补充可能相关的目录（与旧脚本保持相近的覆盖范围）
$extraFolders = @(
    'C:\Windows\SysWOW64\IME\SogouPY'
)

# 强制构造成数组再追加，避免字符串被直接拼接在一起
$allPaths = @()
if ($paths) { $allPaths += $paths }

foreach ($f in $extraFolders) {
    try {
        if (Test-Path $f -PathType Container) {
            $allPaths += $f
        }
    }
    catch {}
}

# 去重
$allPaths = $allPaths | Where-Object { $_ } | Sort-Object -Unique

if (-not $allPaths -or $allPaths.Count -eq 0) {
    Write-Host 'No SogouInput installation found. Please install or specify path manually.'
    exit 1
}

Write-Host 'Detected SogouInput installation directories:'
foreach ($p in $allPaths) { Write-Host " - $p" }

Disable-Network -folderNames $allPaths