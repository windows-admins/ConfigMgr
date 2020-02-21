Import-Module PowerSploit -ErrorAction SilentlyContinue

If (-not (Get-Module -Name PowerSploit))
{
    Write-Host "Could not load PowerSploit module. Is it downloaded and installed?" -ForegroundColor Red
    Write-Host "https://github.com/PowerShellMafia/PowerSploit" -ForegroundColor Cyan
}

Find-ForeignGroup | Select-Object @{expression={$_.GroupDomain}; label='Domain'}, @{expression={$_.GroupName}; label='Group Name'}, @{expression={$_.UserName}; label='User Name'}, @{expression={$_.UserDomain}; label='User Domain'}, @{expression={$_.UserDN}; label='User DN'} | Export-CSV -path ".\ADAudit_ForeignGroup.csv" -NoTypeInformation
