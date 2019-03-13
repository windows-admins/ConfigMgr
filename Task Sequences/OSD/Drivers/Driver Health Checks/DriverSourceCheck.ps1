#This is a quick and dirty script written to just dump the drivers and check to see if the source path/inf exists.
#You will need to be connected to your ConfigMgr drive when you run this (which can be done by launching PowerShell via the console)


Import-Module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager\ConfigurationManager.psd1"

$Drivers = Get-CMDriver

ForEach ($Driver in $Drivers)
{
    #$Driver.ContentSourcePath
    #$Driver.DriverINFFile

    $DriverINF = $Driver.ContentSourcePath + $Driver.DriverINFFile

    #Write-Host "Testing: $DriverINF"

    #if (Test-Path -Path FileSystem::$Driver.ContentSourcePath)
    if (Test-Path -Path $Driver.ContentSourcePath)
    {
        Write-Host "Path does not exist: $Driver.ContentSourcePath"
    }

    #if (Test-Path -Path FileSystem::$Driver.ContentSourcePath+$Driver.DriverINFFile -PathType leaf)
    if (Test-Path -Path $DriverINF -PathType leaf)
    {
        Write-Host "File does not exist: $DriverINF"
    }    
}