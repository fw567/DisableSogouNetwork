#Requires -Version 5.1
#Requires -RunAsAdministrator

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = [Console]::OutputEncoding
} catch {}

function Remove-SogouRules {
    # Remove ALL rules created by the enhanced run script
    # 1) Rules named like: "blocked <path> via script"
    # 2) Rules named like: "Sogou Proxy Detection Block*" (domains, clash port blocks)
    # 3) Optionally remove any leftover standard service rules we might have added

    $patterns = @(
        'blocked * via script',
        'Sogou Proxy Detection Block*',
        'Sogou Pinyin Service'
    )

    $total = 0
    foreach ($pat in $patterns) {
        try {
            $rules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pat }
            $count = ($rules | Measure-Object).Count
            if ($count -gt 0) {
                $rules | Remove-NetFirewallRule -ErrorAction SilentlyContinue | Out-Null
                Write-Host "Removed $count rule(s) matching '$pat'"
                $total += $count
            } else {
                Write-Host "No rules matching '$pat' found" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "Error removing rules matching '$pat': $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "Done. Removed $total rule(s) in total."
}

Remove-SogouRules
