$ErrorActionPreference = “SilentlyContinue”

# Get the current directory
$ScriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition

$Server = $env:computername

# Stop SCCM client
# set-service -Name CcmExec -StartupType disabled
Stop-Service -Name CcmExec -Force

# Remove CCM WMI Name Space
Get-WmiObject -query "Select * From __Namespace Where Name='CCM'" -Namespace "root" -ComputerName $Server | Remove-WmiObject

# Delete C:\windows\SMSCFG.INI
If (test-path "C:\windows\SMSCFG.INI") {remove-item "C:\windows\SMSCFG.INI" -Force}

# Delete Certificates for the SCCM client
If (test-path "$ScriptPath\ccmdelcert.exe") {& "$ScriptPath\ccmdelcert.exe"}

