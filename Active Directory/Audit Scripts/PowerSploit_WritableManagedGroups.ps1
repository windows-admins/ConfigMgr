Import-Module PowerSploit -ErrorAction SilentlyContinue

If (-not (Get-Module -Name PowerSploit))
{
    Write-Host "Could not load PowerSploit module. Is it downloaded and installed?" -ForegroundColor Red
    Write-Host "https://github.com/PowerShellMafia/PowerSploit" -ForegroundColor Cyan
}

Find-ManagedSecurityGroups | Where-Object {$_.CanManagerWrite} | Select-Object @{expression={$_.GroupCN}; label='Group Name'}, @{expression={$_.GroupDN}; label='Group DN'}, @{expression={$_.ManagerCN}; label='Group Manager'}, @{expression={$_.ManagerCN}; label='Manager CN'}, @{expression={$_.ManagerType}; label='Manager Type'} | Export-CSV -path ".\ADAudit_WritableManagedGroups.csv" -NoTypeInformation
