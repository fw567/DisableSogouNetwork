#Requires -Version 5.1
#Requires -RunAsAdministrator

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = [Console]::OutputEncoding
} catch {}

function Find-SogouInstallation {
    $candidatePaths = @()

    $registryPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\SogouInput',
        'HKLM:\SOFTWARE\SogouInput',
        'HKCU:\SOFTWARE\SogouInput'
    )
    foreach ($regPath in $registryPaths) {
        try {
            if (Test-Path $regPath) {
                $prop = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                foreach ($name in @('InstallPath','Path','InstallDir')) {
                    if ($prop.$name) { $candidatePaths += [string]$prop.$name }
                }
            }
        } catch {}
    }

    $candidatePaths += @(
        'C:\Program Files (x86)\SogouInput',
        'C:\Program Files\SogouInput',
        'D:\Program Files (x86)\SogouInput',
        'D:\Program Files\SogouInput',
        'E:\Program Files (x86)\SogouInput',
        'E:\Program Files\SogouInput'
    )

    try {
        $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'sogou' }
        foreach ($p in $procs) {
            try {
                $dir = Split-Path $p.MainModule.FileName -Parent
                if ($dir) { $candidatePaths += $dir }
            } catch {}
        }
    } catch {}

    $valid = @()
    foreach ($path in ($candidatePaths | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Sort-Object -Unique)) {
        try {
            if (-not (Test-Path $path)) { continue }
            $leaf = Split-Path $path -Leaf
            if ($leaf -ne 'SogouInput') { continue }
            $hasExe = Get-ChildItem -Path $path -Recurse -Include *.exe -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^sogou|^sg' }
            if ($hasExe) { $valid += $path }
        } catch {}
    }
    return ($valid | Sort-Object -Unique)
}

function Reset {
    param (
        [string[]] $folderNames
    )

    $stdDisplayName = 'Sogou Pinyin Service'
    # Remove previously created block and proxy rules
    Remove-NetFirewallRule -DisplayName $stdDisplayName -ErrorAction Ignore
    Remove-NetFirewallRule -DisplayName 'Sogou Proxy Detection Block*' -ErrorAction Ignore

    $totalRemoved = 0
    foreach ($folderName in $folderNames) {
        $displayName = "blocked $folderName via script"
        Remove-NetFirewallRule -DisplayName $displayName -ErrorAction Ignore

        # Re-add inbound allow rules like the original script
        $count = 0
        Get-ChildItem -Path $folderName -Recurse *.exe -ErrorAction SilentlyContinue | ForEach-Object -Process {
            New-NetFirewallRule `
                -DisplayName $stdDisplayName `
                -Direction Inbound `
                -Program $_.FullName `
                -Action Allow `
            | Out-Null
            $count += 1
        }
        Write-Host "Added $count inbound allow rules for $folderName"
        $totalRemoved += $count
    }

    Write-Host "Finished. Adjusted rules for $($folderNames.Count) installation(s)."
}

$paths = Find-SogouInstallation
if (-not $paths -or $paths.Count -eq 0) {
    Write-Host 'No SogouInput installation found. Nothing to reset.'
    exit 0
}

Write-Host 'Detected SogouInput directories:'
foreach ($p in $paths) { Write-Host " - $p" }

Reset -folderNames $paths