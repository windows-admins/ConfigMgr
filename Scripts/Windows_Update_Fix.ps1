###################################
#
#Automated Windows Update Fix
#Gleaned from https://support.microsoft.com/en-us/help/971058/how-do-i-reset-windows-update-components
#
###################################

# Services, DLL lists, and locations
$svcList = @(
    "bits", # Background Intelligent Transfer Service
    "wuauserv", #Windows Update Agent Service
    "appidsvc", #Application Identity Service
    "cryptsvc" # Crytographic Service
)
$dllList = @(
    "urlmon.dll", # OLE functions
    "mshtml.dll", # HTML related fucntions
    "shdocvw.dll", # Add basic file and networking ops
    "browseui.dll", # Functions and resources for browser UI mgmt
    "jscript.dll", # Extra functionality to MS JavaScript
    "vbscript.dll", # API functions for VBScript
    "scrrun.dll", # Libraries for reading/writing scripts/text
    "msxml.dll", # IE 4.0+; Parse XML docs
    "msxml3.dll", # Microsoft MSXML 3.0 SP 7
    "msxml6.dll", # Microsoft MSXML 6.0
    "actxprxy.dll", # Functions for marshalling ActiveX COM interfaces
    "softpub.dll", # Functions that support encryption
    "wintrust.dll", # API functions to verify trust in files, catalogs, mem-blobs, sigs, and certs by third parties
    "dssenh.dll", # Microsoft Enhanced DSS and Diffie-Hellman Cryptographic Provider
    "rsaenh.dll", # Implements MS enhanced CSP; 128-bit encryption
    "gpkcsp.dll", # Gemplus CSP
    "sccbase.dll", # Infineon SICRYPT® Base Smart Card CSP
    "slbcsp.dll", # Schlumberger CSP
    "cryptdlg.dll", # Microsoft Common Certificate Dialogs
    "oleaut32.dll", # Core OLE functions
    "ole32.dll",  # Core OLE functions
    "shell32.dll", # Windows Shell API functions
    "initpki.dll", # Microsoft Trust Installation and Setup
    "wuapi.dll", # Windows Update Client API
    "wuaueng.dll", # Microsoft Windows Update
    "wuaueng1.dll", # Windows Update AutoUpdate Engine
    "wucltui.dll", # Windows Update Client UI Plugin
    "wups.dll", # Windows Update client proxy stub
    "wups2.dll", # Windows Update client proxy stub
    "wuweb.dll", # Windows Update Web Control
    "qmgr.dll", # Background Intelligent Transfer Service
    "qmgrprxy.dll", # Background Intelligent Transfer Service
    "wucltux.dll", # Windows Update Client User Experience 
    "muweb.dll", # Microsoft Update Web Control
    "wuwebv.dll" # Windows Update Vista Web Control  
)
$userDL = "$env:ALLUSERSPORFILE\Microsoft\Network\Downloader"
$swdFolder = "$env:WINDIR\SoftwareDistribution"
$cr2Folder = "$env:WINDIR\system32\catroot2"

# Stop BITS, WU, and Cryptographic services
Get-Service -Name $svcList | Set-Service -StartupType Automatic -Status Stopped

# Delete qmgr*.dat files under %ALLUSERSPROFILE%
If (Test-path $userDL) {
    Get-ChildItem $userDL -Recurse -Force -Include qmgr*.dat | Remove-Item -Force
    Write-Host "Deleting qmgr*.dat from the All Users Profile."
}

# Aggressive approach: Rename the Software Distribution & catroot2 folder's backup copies   
    # First, check to see if its been done already; remove .bak if so, then rename current folder
    If (Test-Path ($swdFolder + ".bak")) {
        Remove-Item ($swdFolder + ".bak") -Recurse
        Write-Host "$swdFolder.bak deleted; renaming current folder."
        Rename-Item $swdFolder "SoftwareDistribution.bak"
    } Else {
        Write-Host "$swdFolder.bak does not exist; renaming current folder"
        Rename-Item $swdFolder "SoftwareDistribution.bak"
    }
    If (Test-Path ($cr2Folder + ".bak")) {
        Remove-Item ($cr2Folder + ".bak")
        Write-Host "$cr2Folder.bak deleted; renaming current folder."
        Rename-Item $cr2Folder "catroot2.bak"
    } Else {
        Write-Host "$cr2Folder.bak does not exist; renaming current folder."
        Rename-Item $cr2Folder "catroot2.bak"
    }
    # Reset BITS and WU service to the default descriptor
    cmd /c "sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
    cmd /c "sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"

#Re-register BITS and WU DLLs
ForEach ($dll in $dllList) {

    If (Test-Path $env:WINDIR\system32\$dll) {
        regsvr32.exe /s $env:WINDIR\system32\$dll
        Write-Host "Registering $dll."
    } Else {
        Write-Host "$dll does not exist on your system."
    }
}

# Reset WinSock and WinHTTP Proxy
netsh winsock reset
netsh winhttp reset proxy

# Restart BITS, WU, and Cryptographic services
Get-Service -Name $svcList | Set-Service -StartupType Automatic -Status Running
