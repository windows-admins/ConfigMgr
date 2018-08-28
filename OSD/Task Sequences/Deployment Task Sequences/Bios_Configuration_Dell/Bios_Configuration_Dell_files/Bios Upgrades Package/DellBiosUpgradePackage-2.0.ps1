<#Added TS Variables for if using during OSD.  Creates Variable SMSTS_BiosUpdate, and sets to TRUE. (For Future Use)
	http://powershelldistrict.com/how-to-read-and-write-sccm-task-sequence-variables-with-powershell/

#>
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
$tsenv.Value("SMSTS_BiosUpdate") = "True"

#Create Log Path
$LogPath = $tsenv.Value("_SMSTSLogPath")

#Get Bios Password from File
$BiosPassword = Get-Content .\Bios.txt

#Create Model Variable
$ComputerModel = Get-WmiObject -Class Win32_computersystem | Select-Object -ExpandProperty Model

#Get Current BIOS Version
$currentBios = Get-WmiObject -Class Win32_BIOS | Select-Object -ExpandProperty SMBIOSBIOSVersion

#Get Bios File Name (Uses the Bios EXE file in the same folder)
$BiosFileName = Get-ChildItem $ComputerModel\*.exe -Verbose | Select -ExpandProperty Name

#Get Bios File Name (No Extension, used to create Log File)
$BiosLogFileName = Get-ChildItem $ComputerModel\*.exe -Verbose | Select -ExpandProperty BaseName

#check if bios current
If(!($BiosLogFileName -contains $currentBios)){
   #Copy Bios Installer to the root of the package - the Flash64W didn't like when I left it in the Computer Model folder, because it has spaces. (Yes, I tried qoutes and stuff)
    Copy-Item $ComputerModel\*.exe -Destination $PSScriptRoot

    $BiosLogFileName = "$BiosLogFileName.log"
    
    #Set Command Arguments for Bios Update
    $cmds = "/b=$BiosFileName /s /l=$LogPath\$BiosLogFileName"
    #$cmds = "/b=$BiosFileName /s /p=$BiosPassword /l=$LogPath\$BiosLogFileName"

    #Update Bios
    $Process = start-process $PSScriptRoot\Flash64W.exe  -ArgumentList $cmds -PassThru -wait


    #Creates and Set TS Variable to be used to run additional steps if reboot requried.
    if ($process.ExitCode -eq 2)
        {$tsenv.Value("SMSTS_BiosUpdateRebootRequired") = "True"}
    else
        {$tsenv.Value("SMSTS_BiosUpdateRebootRequired") = "False"}
    
    if ($process.ExitCode -eq 10)
        {$tsenv.Value("SMSTS_BiosUpdateBatteryCharge") = "True"}
        else
        {$tsenv.Value("SMSTS_BiosUpdateBatteryCharge") = "False"}
}