Import-Module PowerSploit -ErrorAction SilentlyContinue

If (-not (Get-Module -Name PowerSploit))
{
    Write-Host "Could not load PowerSploit module. Is it downloaded and installed?" -ForegroundColor Red
    Write-Host "https://github.com/PowerShellMafia/PowerSploit" -ForegroundColor Cyan
}

Get-NetGPOGroup | 
Select-Object @{expression={$_.GPODisplayName}; label=’GPO Display Name’}, @{expression={$_.GPOName}; label=’GUID’}, @{expression={$_.GPOType}; label=’GPO Type’}, @{expression={$_.GroupName}; label=’Group Name’}, @{expression={$_.GroupSID}; label=’Group SID’} | 
Export-Csv -Path .\ADAudit_ADGroupsinGPOs.csv -NoTypeInformation
