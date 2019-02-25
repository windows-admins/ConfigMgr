<#
    .DESCRIPTION
        ***Integral Design of Just In Time Modern Driver Management***
        This is ideally used in one of two difference scenarios:
        1) To stage drivers for an Upgrade in Place (UIP) scenario.  You can use this to download just the drivers required by the OS, either to prestage or directly as part of the UIP task sequence.
        2) To update online workstations (keeping drivers up to date).
    .PARAMETER $Path
        Path to the desired location to download drivers to.
    .PARAMETER $SCCMServer
        SCCM server to connect to. Note that this is where the SQL database lives (typically on the MP).
    .PARAMETER $SCCMDistributionPoint
        IIS server to connect to. Note that this is typically the Distribution Point.
    .PARAMETER Credential
        Credentials to use for querying SQL and IIS.
    .PARAMETER Categories
        An array of categories to use for searching for drivers. Categories are inclusive not exclusive.
        Format must be as follows: @("9370","Test")
    .PARAMETER CategoryWildCard
        If set will search for categories using wild cards.  Thus "9370" would match both "Dell XPS 13 9370" and "Contoso 9370 Performance Pro Plus" 
    .PARAMETER SCCMServerDB
        The database name.  Standard format is "ConfigMgr_" followed by the site code 
    .PARAMETER InstallDrivers
        Enable installation of drivers.  Disable for use in testing or prestage scenarios.
    .PARAMETER DownloadDrivers
        Enable downloading of drivers.  Typically only turned off for debugging/testing scenarios.
    .PARAMETER FindAllDrivers
        Will download and install all drivers regardless if it's a newer version or not
        Warning: use this carefully as it will typically cause a large amount of drivers to be downloaded and installed
    .PARAMETER HardwareMustBePresent
        If set only hardware that is currently present to the OS will be downloaded and installed.  Turning this on will try and find drivers for any device ever connected to the workstation, while turning it off may miss devices that aren't currently connected (docks, dongles, etc).
    .PARAMETER UpdateOnlyDatedDrivers
        Enabling this will only download and install drivers that are newer than what is currently installed on the operating system.
    .PARAMETER HTTPS
        Enable to force the site to use HTTPS connections.  Default is HTTP.
    .INPUTS
        None. You cannot pipe objects in.
    .OUTPUTS
        None. Does not generate any output.
    .EXAMPLE
        .\AutoApplyDrivers.ps1 -Path "c:\Temp\Drivers\" -SCCMServer cm1.corp.contoso.com -SCCMServerDB "ConfigMgr_CHQ" -Credential (Get-Credential -UserName "CORP\Drivers" -Message "Enter password")
        Runs with passed in configuration and prompts user running for credentials (useful for debugging)
    .EXAMPLE
        .\AutoApplyDrivers.ps1
        Uses default configuration and runs under the current session
#>

Param(
    $Path = (Get-ChildItem env:SystemDrive).Value+"\Drivers\",
    [string]$SCCMServer = "cm1.corp.contoso.com",
    $Credential,
    # $Credential = (Get-Credential -UserName 'CORP\Drivers' -Message "Enter password"),
    [System.Array]$Categories = @(), # @("9370","Test")
    [bool]$CategoryWildCard = $False,
    [string]$SCCMServerDB = "ConfigMgr_CHQ",
    [bool]$InstallDrivers = $False,
    [bool]$DownloadDrivers = $True,
    [bool]$FindAllDrivers = $False,
    [bool]$HardwareMustBePresent = $True,
    [bool]$UpdateOnlyDatedDrivers = $True, # Use this to exclude any drivers we already have updated on the system
    [bool]$HTTPS = $True,
    [string]$SCCMDistributionPoint
)

# _SMSTSSiteCode = CHQ

Try
{
    #Import Modules
    Remove-Module $PSScriptRoot\MODULE_Functions -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Import-Module $PSScriptRoot\MODULE_Functions -Force -WarningAction SilentlyContinue
}
Catch
{
    Write-Host -ForegroundColor Red "Unable to import modules.  Check that the source files exist."
    Exit 1
}

# __________________________________________________________________________________
#
# Handle $Path and make sure it's not missing, if it is set to the script directory.
# __________________________________________________________________________________
Try
{
    If (-not $Path)
    {
        Write-Host -ForegroundColor Red "Path is missing, defaulting to script execution directory."
        $Path = $PSScriptRoot
    }

    If(-not (test-path $Path))
    {
          New-Item -ItemType Directory -Force -Path $Path
    }

    $Global:LogFile = Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log"
}
Catch
{
    Handle-Error -Message "Critical error handling the Path variable." -Exception $_ -ExitCode 1
} 

LogIt -message (" ") -component "Main()" -type "Info"
LogIt -message (" ") -component "Main()" -type "Info"
LogIt -message ("_______________________________________________________________________") -component "Main()" -type "Info"

# __________________________________________________________________________________
#
LogIt -message ("Getting Task Squence environment and variables") -component "Main()" -type "Info"
# __________________________________________________________________________________
Try
{
    $tsenv = Get-TSEnvironment

    If ($tsenv)
    {
        LogIt -message ("Running in a task sequence.") -component "Main()" -type "Info"

        If ($tsenv.TSVar_Path)
        {
            $Path = $tsenv.TSVar_Path
        }
        If ($tsenv.TSVar_SCCMServerDB)
        {
            $SCCMServerDB = $tsenv.TSVar_SCCMServerDB
        }
        If ($tsenv.TSVar_Categories)
        {
            $Categories = $tsenv.TSVar_Categories
        }
        If ($tsenv.TSVar_InstallDrivers)
        {
           $InstallDrivers = [bool]$tsenv.TSVar_InstallDrivers
        }
        If ($tsenv.TSVar_DownloadDrivers)
        {
           $DownloadDrivers = [bool]$tsenv.TSVar_DownloadDrivers
        }
        If ($tsenv.TSVar_FindAllDrivers)
        {
           $FindAllDrivers = [bool]$tsenv.TSVar_FindAllDrivers
        }
        If ($tsenv.TSVar_HardwareMustBePresent)
        {
           $HardwareMustBePresent = [bool]$tsenv.TSVar_HardwareMustBePresent
        }
        If ($tsenv.TSVar_UpdateOnlyDatedDrivers)
        {
           $UpdateOnlyDatedDrivers = [bool]$tsenv.TSVar_UpdateOnlyDatedDrivers
        }
        If ($tsenv.TSVar_UpdateOnlyDatedDrivers)
        {
           $UpdateOnlyDatedDrivers = [bool]$tsenv.TSVar_UpdateOnlyDatedDrivers
        }
    }
    Else
    {
        LogIt -message ("Not running in a task sequence.") -component "Main()" -type "Verbose"
    }

}
Catch
{
    Handle-Error -Message "Critical error getting the task sequence environment and variables." -Exception $_ -ExitCode 1
}


# __________________________________________________________________________________
#
LogIt -message ("Validate required parameters and what context this is being run under") -component "Main()" -type "Info"
# __________________________________________________________________________________
Try
{
    If (-not $SCCMDistributionPoint)
    {
        $SCCMDistributionPoint = $SCCMServer
    }

    $_ = Validate-CriticalParameters -Parameters @($Path,$SCCMServer,$SCCMServerDB)

    If ($_ -gt 0)
    {
        LogIt -message ("Missing critical information:") -component "Main()" -type "Error"
        LogIt -message ("Path: "+$Path) -component "Main()" -type "Error"
        LogIt -message ("SCCMServer: "+$SCCMServer) -component "Main()" -type "Error"
        LogIt -message ("SCCMServerDB: "+$SCCMServerDB) -component "Main()" -type "Error"
        LogIt -message ("Exiting....") -component "Main()" -type "Error"
        Exit 1
    }

    If (-not $Credential -and $tsenv.TSVar_Username -and $tsenv.TSVar_Password)
    {
        LogIt -message ("Running as: "+$tsenv.TSVar_Username) -component "Main()" -type "Info"

        $Credential = New-Object System.Management.Automation.PSCredential($tsenv.TSVar_Username,$tsenv.TSVar_Password)
        $Credential | Add-Member -name "ClearTextPassword" -type NoteProperty -value $tsenv.Value($tsenv.TSVar_Password)
    }
    ElseIf(-not $Credential)
    {
        LogIt -message ("Running under current credentials.") -component "Main()" -type "Info"
    }
    Else
    {
        LogIt -message ("Running as: "+$Credential.UserName.ToString()) -component "Main()" -type "Info"
    }
}
Catch
{
    Handle-Error -Message "Critical error validating required parameters and credentials." -Exception $_ -ExitCode 1
}


LogIt -message ("Starting execution....") -component "Main()" -type "Info"


# __________________________________________________________________________________
#
LogIt -message ("Get local device hardware list and generate XML") -component "Main()" -type "Info"
# __________________________________________________________________________________
Try
{
    # Need to get local drivers and build out the XML
    LogIt -message ("Generating XML from list of devices on the device") -component "Main()" -type "Verbose"

    $hwidtable = New-Object System.Data.DataTable
    $hwidtable.Columns.Add("FriendlyName","string") | Out-Null
    $hwidtable.Columns.Add("HardwareID","string") | Out-Null

    $xmlCategories = Query-XMLCategory -fCategories $Categories

    $Devices = Get-PnpDevice
    $Devices | Sort-Object | Format-Table -Wrap -AutoSize -Property Class, FriendlyName, InstanceId | Out-File -FilePath (Join-Path -Path $Path -ChildPath "PnPDevices.log")
    If ($HardwareMustBePresent)
    {
        $Devices = $Devices | Where-Object {$_.Present}
    }

    $xmlDevices = Query-XMLDevices -fDevices $Devices
    $xmlDevicesPretty = Query-XMLDevices -fDevices $Devices -fPrettyPrint

    $xml = "<DriverCatalogRequest>"
    If ($xmlCategories)
    {
        $xml = $xml+$xmlCategories
    }
    $xml = $xml+"<Devices>"

    $xmlpretty = $xml+$xmlDevicesPretty+"</Devices></DriverCatalogRequest>"
    $xml = $xml+$xmlDevices+"</Devices></DriverCatalogRequest>"

    $xmlpretty = $xmlpretty.Replace("<Device></Device>","")
    $xml = $xml.Replace("<Device></Device>","")

    Write-Output $xmlpretty | Format-Xml | Out-File -FilePath (Join-Path -Path $Path -ChildPath "DriversPretty.xml")
    if ($DebugPreference -ne "SilentlyContinue")
    {
        Write-Output $xml | Format-Xml | Out-File -FilePath (Join-Path -Path $Path -ChildPath "DriversToMP.xml")
    }
}
Catch
{
    Handle-Error -Message "Critical error Getting local drivers and formatting XML to send to SQL." -Exception $_ -ExitCode 1
}


# __________________________________________________________________________________
#
LogIt -message ("Query SQL Stored Procedure to get list of drivers from SCCM.") -component "Main()" -type "Info"
# __________________________________________________________________________________
Try
{
    # Run the drivers against the stored procs to find matches
    LogIt -message ("Querying MP for list of matching drivers.") -component "Main()" -type "Verbose"

    if ($Credential)
    {
        $drivers = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name MP_MatchDrivers -Parameter $xml -Credential $Credential
    }
    else
    {
        $drivers = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name MP_MatchDrivers -Parameter $xml
    }

    if ($drivers[0] -eq 0)
    {
        LogIt -message ("No valid drivers found.  Exiting.") -component "Main()" -type "Warning"
        Exit 119
    }

    LogIt -message ("Found the following drivers (CI_ID):") -component "Main()" -type "Debug"
    LogIt -message ("$drivers.CI_ID") -component "Main()" -type "Debug"

    $CI_ID_list = "("
    $count = 0

    ForEach ($CI_ID in $drivers.CI_ID)
    {
        if ($count -eq 0)
        {
            $CI_ID_list += "$CI_ID"
        }
        else
        {
            $CI_ID_list += ", $CI_ID"
        }
        $count++
    }

    $CI_ID_list += ")"
}
Catch
{
    Handle-Error -Message "Critical error quering SQL Stored Procedure to get list of drivers from SCCM" -Exception $_ -ExitCode 1
}


# __________________________________________________________________________________
#
LogIt -message ("Getting additional driver information and creating list of drivers to download/install.") -component "Main()" -type "Info"
# __________________________________________________________________________________
Try
{
    LogIt -message ("Querying additional driver information for matching drivers.") -component "Main()" -type "Verbose"

    $SqlQuery = "SELECT CI_ID, DriverType, DriverINFFile, DriverDate, DriverVersion, DriverClass, DriverProvider, DriverSigned, DriverBootCritical FROM v_CI_DriversCIs WHERE CI_ID IN $CI_ID_list"

    if ($Credential)
    {
        $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery -Credential $Credential
    }
    else
    {
        $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery
    }

    If ($DebugPreference -ne "SilentlyContinue")
    {
        $return | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "v_CI_DriversCIs.log")
    }

    Try
    {
        $DriverListAll = $return[1] | Sort-Object -Property @{Expression = "DriverINFFile"; Descending = $False}, @{Expression = "DriverDate"; Descending = $True}, @{Expression = "DriverVersion"; Descending = $True} 
        $DriverList = @()
    }
    Catch
    {
        LogIt -message ("Unable to find valid driver information. Exiting...") -component "Main()" -type "Error"
        Exit 1
    }


    If ($FindAllDrivers)
    {
        $DriverList = $DriverListAll
    }
    Else
    {
        ForEach ($_ in $DriverListAll)
        {
            If (($DriverList.DriverINFFile -contains $_.DriverINFFile) -and ($DriverList.DriverClass -contains $_.DriverClass) -and ($DriverList.DriverProvider -contains $_.DriverProvider))
            {
                LogIt -message ("Newer driver already exists, skipping.") -component "Main()" -type "Debug"
            }
            Else
            {
                LogIt -message ("Adding driver to list." ) -component "Main()" -type "Debug"
                $DriverList += $_
            }
        }
    }


    If (Query-IfAdministrator)
    {
        $DriverListFinal = Query-DriverListAgainstOnlineOS -fDriverList $DriverList
    }
    Else
    {
        $DriverListFinal = "Not running as administrator.  Unable to check SCCM drivers against local drivers to see if the local drivers are newer than targetted drivers."
        LogIt -message ($DriverListFinal) -component "Main()" -type "Warning"
        $UpdateOnlyDatedDrivers = $False # Force this to false so we don't try and do this.
    }

    "All drivers found:" | Out-String | Out-File -FilePath (Join-Path -Path $Path -ChildPath "SCCMDrivers.log")
    $DriverListAll | Format-Table | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "SCCMDrivers.log")
    "" | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "SCCMDrivers.log")
    "Targeted drivers:" | Out-String | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "SCCMDrivers.log")
    $DriverList | Format-Table | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "SCCMDrivers.log")
    "" | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "SCCMDrivers.log")
    "Drivers Newer than Current:" | Out-String | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "SCCMDrivers.log")
    $DriverListFinal | Format-Table | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "SCCMDrivers.log")


    If ($UpdateOnlyDatedDrivers)
    {
        $DriverList = $DriverListFinal
    }
}
Catch
{
    Handle-Error -Message "Critical error getting additional driver information and creating list of drivers to download/install." -Exception $_ -ExitCode 1
}


# __________________________________________________________________________________
#
# 
LogIt -message ("Maping drivers to content download location.") -component "Main()" -type "Info"
LogIt -message ("Parse CI_ID against v_DriverContentToPackage to get the Content_UniqueID") -component "Main()" -type "Verbose"
# __________________________________________________________________________________
Try
{
    $Content_UniqueID = @()

    ForEach ($CI_ID in ($DriverList.CI_ID | Sort-Object | Get-Unique)){
        $SqlQuery = "SELECT * FROM v_DriverContentToPackage WHERE CI_ID = '$CI_ID'"
        # $return = Invoke-SqlQuery -ServerName $SCCMServer -Database $SCCMServerDB -Query $SqlQuery -Credential $Credential

        if ($Credential)
        {
            $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery -Credential $Credential
        }
        else
        {
            $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery
        }

        $Content_UniqueID += $return.Content_UniqueID
    }

    $Content_UniqueIDs = $Content_UniqueID | Sort-Object | Get-Unique
}
Catch
{
    Handle-Error -Message "Critical error parsing CI_ID against v_DriverContentToPackage to get the Content_UniqueID." -Exception $_ -ExitCode 1
}


# __________________________________________________________________________________
#
LogIt -message ("Downloading drivers") -component "Main()" -type "Info"
# __________________________________________________________________________________
Try
{
    If ($DownloadDrivers)
    {
        If ($Content_UniqueIDs)
        {
            # Download drivers
            # TODO: Add ability to select DP

            LogIt -message ("Parsing Found Drivers: "+$Content_UniqueIDs) -component "Main()" -type "Debug"

            ForEach ($Content_UniqueID in $Content_UniqueIDs)
            {
                LogIt -message ("Parsing Content_UniqueID: "+$Content_UniqueID) -component "Main()" -type "Debug"

                If ($Credential)
                {
                    LogIt -message ("Calling Download-Drivers with credentials") -component "Main()" -type "Verbose"

                    If($HTTPS)
				    {
                	    Download-Drivers -fDriverGUID $Content_UniqueID -fSCCMDistributionPoint $SCCMDistributionPoint -fCredential $Credential -fHTTPS $HTTPS
                    }
				    Else
				    {
                	    Download-Drivers -fDriverGUID $Content_UniqueID -fSCCMDistributionPoint $SCCMDistributionPoint -fCredential $Credential
                    }
                }
                else
                {
                    LogIt -message ("Calling Download-Drivers without credentials") -component "Main()" -type "Verbose"

                    If($HTTPS)
				    {
                	    Download-Drivers -fDriverGUID $Content_UniqueID -fSCCMDistributionPoint $SCCMDistributionPoint -fHTTPS $HTTPS
                    }
				    Else
				    {
                	    Download-Drivers -fDriverGUID $Content_UniqueID -fSCCMDistributionPoint $SCCMDistributionPoint
                    }
                }
            }
        }
        Else
        {
            LogIt -message ("No drivers found to download.") -component "Main()" -type "Warning"
        }
    }
    Else
    {
        LogIt -message ("Skipping downloading of drivers.") -component "Main()" -type "Warning"
    }
}
Catch
{
    Handle-Error -Message "Critical error downloading drivers" -Exception $_ -ExitCode 1
}

 
# __________________________________________________________________________________
#
LogIt -message ("Inject the drivers into the OS") -component "Main()" -type "Info"
LogIt -message ("Run pnputil") -component "Main()" -type "Verbose"
# __________________________________________________________________________________
Try
{
    if ($InstallDrivers)
    {
        If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] “Administrator”))
        {

            LogIt -message ("Apply downloaded drivers to online operating system.") -component "Main()" -type "Verbose"

            Install-Drivers
        }
        Else
        {
            LogIt -message ("Not running as administrator.  Unable to install drivers.") -component "Main()" -type "Error"
        }
    }
    else
    {
        LogIt -message ("Skipping installation of drivers.") -component "Main()" -type "Warning"
    }
}
Catch
{
    Handle-Error -Message "Critical error Inject the drivers into the OS" -Exception $_ -ExitCode 1
}

LogIt -message ("Script Execution Complete") -component "Main()" -type "Info"
LogIt -message (" ") -component "Main()" -type "Info"
LogIt -message (" ") -component "Main()" -type "Info"

# :beer: