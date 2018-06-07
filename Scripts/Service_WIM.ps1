[CmdletBinding(DefaultParameterSetName='FullOptions')]
param(
[Parameter(Mandatory=$false, ParameterSetName="IndexOnly")]
[switch]$IndexOnly,
[Parameter(Mandatory=$true, ParameterSetName="FullOptions")]
[parameter(Mandatory=$true, ParameterSetName = "IndexOnly")]
[string]$WinVersion,
[Parameter(Mandatory=$True, ParameterSetName="FullOptions") ]
[parameter(Mandatory=$true, ParameterSetName = "IndexOnly")]
[String]$SourceImage,
[Parameter(Mandatory=$True,ParameterSetName = "FullOptions")]
[String]$MountDir,
[Parameter(Mandatory=$True,ParameterSetName = "FullOptions")]
[String]$DestinationImage
)

#Create an empty directory to mount the .wim file to.
    #C:\WIM

#Place all update files (.cab or .msu) you'd like serviced into the .wim file in the same directory as the .wim. Ex:
    #C:\WIM-Servicing\
    #C:\WIM-Serviving\install.wim
    #C:\Wim-Servicing\windows10.0-kb4100347-x64.msu
    #C:\Wim-Servicing\windows10.0-kb4100403-x64.msu
#The script will add them to the .wim automatically.

#Command line usage examples:
# Export a single Index, add updates, optimize .wim
#      Service_WIM.ps1 -SourceImage "C:\WIM-Source\install.wim" -MountDir "C:\WIM" -DestinationImage "C:\WIM-Source\install-new.wim" -WinVersion "Windows 10 Enterprise"
# Remove Indexes only
#      Service_WIM.ps1 -IndexOnly -SourceImage "C:\WIM-Source\install.wim" -WinVersion "Windows 10 Enterprise" -DestinationImage "C:\WIM-Source\install-new.wim"

#Index names available as of 1803:
# Windows 10 Education, Windows 10 Education N, Windows 10 Enterprise, Windows 10 Enterprise N, Windows 10 Pro, Windows 10 Pro N, Windows 10 Pro Education, Windows 10 Pro Education N, Windows 10 Pro for Workstations, Windows 10 Pro N for Workstations

#DISM commands courtesy of @LTBehr
#Export Index method courtesy of @danpadgett

#Check to ensure directory to mount .wim file to is empty. -force to look for hidden files.
$MountDirInfo = Get-ChildItem $MountDir -Force | Measure-Object
if ($MountDirInfo.Count -ne 0){
Write-Host "$MountDir is not empty (including hidden files). Please resolve and try again."
Exit
}

#Check for Windows 10 ADK DISM. If it is installed, use that instead of built in version.
if (Test-Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe") {$dism = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" } else {$dism = "dism.exe"}

#Export specified Index.
Write-Host "Exporting Single Index..."
#Check for existence of destination image file for export. If it already exists, dism will not error out and just add another index, so it needs to be removed.
if ((Test-Path $DestinationImage) -eq $True) {Write-Host "Destination image file, $DestinationImage, already exists. Please remove the file and re-run the script. Otherwise, DISM will reuse the existing file and add another index."
    Exit}
#The mount image step had a problem where dism did not return complete using a standard -wait switch and hung the script. Using the WaitForExit method, which fixed this, for all dism commands for consistency.

$dism_wait = Start-Process $dism -PassThru -ArgumentList "/export-image /SourceImageFile:$SourceImage /SourceName:`"$WinVersion`" /DestinationImageFile:$DestinationImage"
$dism_wait.WaitForExit()
If ($dism_wait.ExitCode -ne 0) {
    Write-Host "Error exporting index."
    Write-Host "You can check C:\Windows\Logs\DISM\dism.log for errors."
    Exit
}

#If -IndexOnly switch was not used, run DISM commands to add updates and optimize the .wim file.
if ($IndexOnly -eq $False)
    {
    #Mount .wim for dism actions.
    Write-Host "Mounting Image..."
    Write-Host "Do not open $MountDir in Explorer while the script is running."
    $dism_wait = Start-Process $dism -PassThru -ArgumentList "/mount-image /ImageFile:$DestinationImage /Index:1 /MountDir:$MountDir"
    $dism_wait.WaitForExit()
    If ($dism_wait.ExitCode -ne 0) {
        Write-Host "Error Mounting .wim file."
        Write-Host "You can check C:\Windows\Logs\DISM\dism.log for errors."
        Exit
        }
    #Add update package(s) to mounted WIM.
    $UpdateFiles = Get-ChildItem -Path (Get-Item $DestinationImage).Directory.FullName -Recurse -Include *.msu,*.cab
    foreach ($UpdateFile in $UpdateFiles) {
        Write-Host "Adding Update: $UpdateFile"
        $dism_wait = Start-Process $dism -PassThru -Argumentlist "/Image:$MountDir /Add-Package /PackagePath:$UpdateFile"
        $dism_wait.WaitForExit()
        If ($dism_wait.ExitCode -ne 0) {
            Write-Host "Error adding $UpdateFile. Discarding changes to .wim file."
            Write-Host "You can check C:\Windows\Logs\DISM\dism.log for errors."
            $dism_wait = Start-Process $dism -PassThru -ArgumentList "/unmount-image /MountDir:$MountDir /discard"
            $dism_wait.WaitForExit()  
            Exit
            }
        }
    #Cleanup .wim
    Write-Host "Cleaning Up WIM..."
    $dism_wait = Start-Process $dism -PassThru -Argumentlist "/Image:$MountDir /Cleanup-Image /StartComponentCleanup /ResetBase"
    $dism_wait.WaitForExit()
    If ($dism_wait.ExitCode -ne 0) {
        Write-Host "Error running DISM Image Cleanup. Discarding changes to .wim file."
        Write-Host "You can check C:\Windows\Logs\DISM\dism.log for errors."
        $dism_wait = Start-Process $dism -PassThru -ArgumentList "/unmount-image /MountDir:$MountDir /discard"
        $dism_wait.WaitForExit()  
        Exit
        }
    #Unmount .wim and save changes.
    Write-Host "Unmounting WIM..."
    $dism_wait = Start-Process $dism -PassThru -ArgumentList "/unmount-image /MountDir:$MountDir /Commit"
    $dism_wait.WaitForExit()    
    If ($dism_wait.ExitCode -ne 0) {
        Write-Host "Error saving changes to the WIM file. WIM is likely still mounted to $MountDir and may require manual attention." -Foregroundcolor Red
        Write-Host "You can check C:\Windows\Logs\DISM\dism.log for errors."
    }
    }