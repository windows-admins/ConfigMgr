<#
    .Synopsis
        This script will retrive autologon credentials from ConfigMgr Task Sequence variables and set them using Sysinternals Autologon.exe.
    .Example
        ./Autologon.ps1
    .Description
        This script will retrive autologon credentials from ConfigMgr Task Sequence variables and set them using Sysinternals Autologon.exe.
        It requires Autologon.exe within the same content location as this script.
    .Notes
        NAME: Autologon.ps1
        AUTHOR: Anthony Fontanez (ajfrcc@gmail.com)
        VERSION: 1.0
        LASTEDIT: 2017-04-15
        CHANGELOG:
            1.0 (2017-04-15) Initial script creation
#>

$LogFile = "$env:SystemDrive\Logs\Autologon.log"

Start-Transcript -Path "$LogFile" | Out-Null

$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$AutologonUsername = $TSEnv.Value("AutologonUsername")
$AutologonPassword = $TSEnv.Value("AutologonPassword")
$AutologonDomain  = $TSEnv.Value("AutologonDomain")
$RegistryPath = "HKCU:\Software\Sysinternals\Autologon"
$Name = "EulaAccepted"
$Value = "1"
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

New-Item -Path $RegistryPath -Force
New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType DWORD -Force
Start-Process -FilePath "$($ScriptDirectory)\Autologon.exe" -ArgumentList "$AutologonUsername $AutologonDomain $AutologonPassword"

Stop-Transcript | Out-Null