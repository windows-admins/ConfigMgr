Import-Module PowerSploit -ErrorAction SilentlyContinue

If (-not (Get-Module -Name PowerSploit))
{
    Write-Host "Could not load PowerSploit module. Is it downloaded and installed?" -ForegroundColor Red
    Write-Host "https://github.com/PowerShellMafia/PowerSploit" -ForegroundColor Cyan
}

Get-GPPPassword | 
Select-Object @{expression={$_.UserNames}; label=’User Name’}, @{expression={$_.Passwords}; label=’Passwords’}, @{expression={$_.NewName}; label=’New Name’},@{expression={$_.Changed}; label=’Changed’}, @{expression={(Get-GPO -Guid $_.File.Split("\")[6]).DisplayName}; label='Group Policy Name'}, @{expression={$_.File}; label=’File’} | 
Export-Csv -Path .\ADAudit_ExposedGPPPasswords.csv -NoTypeInformation

# Does not work yet
# $GPPAutoLogon = Get-GPPAutologon

