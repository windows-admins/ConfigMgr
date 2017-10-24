###################################
#
#Automated Windows Update Fix
#https://support.microsoft.com/en-us/help/971058/how-do-i-reset-windows-update-components
#
###################################

#Set services we'll be stopping and starting
$services = "bits","wuauserv","appidsvc","cryptsvc"

#Stop services
foreach ($service in $services) {Stop-Service $service}

#Remove all Downloader qmgr*.dat files
if (test-path "$env:ALLUSERSPROFILE\Microsoft\Network\Downloader\") {get-childitem "$env:ALLUSERSPROFILE\Microsoft\Network\Downloader\" -recurse -force -include qmgr*.dat | remove-item -force}

#Agressive - Microsoft recommends skipping this on first attempt at fix.
#Have we run the fix previously?
if (test-path $env:WINDIR\SoftwareDistribution.bak) {Remove-Item $env:WINDIR\SoftwareDistribution.bak -Recurse}
if (test-path $env:WINDIR\System32\catroot2.bak) {Remove-Item $env:WINDIR\System32\catroot2.bak -Recurse}
#Otherwise, rename folders
if (test-path $env:WINDIR\SoftwareDistribution) {Rename-Item -path $env:WINDIR\SoftwareDistribution -newname SoftwareDistribution.bak}
if (test-path $env:WINDIR\System32\catroot2) {Rename-Item -path $env:WINDIR\System32\catroot2 -newname catroot2.bak}
#Set BITS and WU Service Security Descriptors
cmd /c "sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
cmd /c "sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
#End Agressive

#Re-register DLLs
$dll_list = "atl.dll","urlmon.dll","mshtml.dll","shdocvw.dll","browseui.dll","jscript.dll","vbscript.dll","scrrun.dll","msxml.dll","msxml3.dll","msxml6.dll","actxprxy.dll","softpub.dll","wintrust.dll","dssenh.dll","rsaenh.dll","gpkcsp.dll","sccbase.dll","slbcsp.dll","cryptdlg.dll","oleaut32.dll","ole32.dll","shell32.dll","initpki.dll","wuapi.dll","wuaueng.dll","wuaueng1.dll","wucltui.dll","wups.dll","wups2.dll","wuweb.dll","qmgr.dll","qmgrprxy.dll","wucltux.dll","muweb.dll","wuwebv.dll"
foreach ($dll in $dll_list) {regsvr32.exe /s $env:WINDIR\system32\$dll}

#Reset winsock and proxy
netsh winsock reset
netsh winhttp reset proxy

#Start services
foreach ($service in $services) {Start-Service $service}
