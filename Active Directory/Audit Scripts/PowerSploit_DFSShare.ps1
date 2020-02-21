Import-Module PowerSploit -ErrorAction SilentlyContinue

If (-not (Get-Module -Name PowerSploit))
{
    Write-Host "Could not load PowerSploit module. Is it downloaded and installed?" -ForegroundColor Red
    Write-Host "https://github.com/PowerShellMafia/PowerSploit" -ForegroundColor Cyan
}

Get-DFSshare | 
Select-Object @{expression={$_.RemoteServerName}; label=’Remote Server Name’}, @{expression={$_.Name}; label=’Share Name’} | 
Export-Csv -Path .\ADAudit_ExposedDFSShare.csv -NoTypeInformation
