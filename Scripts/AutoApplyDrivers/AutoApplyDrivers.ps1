<#
    ALL THESE ARE WRONG! NEED TO UPDATE
    .DESCRIPTION
        Creates Application and Deployment Types.
        This script is run against an XML file, and then can deploy applications to Development, Production, or Retire them.
    .PARAMETER $XMLDocument
        Path to the XML document to read, where the applications that need to be modified (created, moved into Production, or Retired) are documented.
    .PARAMETER $Action
        Action to be taken against the XML Document.  Provided actions are Development, Production, or Retired.
    .PARAMETER CMSite
        CM site code
    .PARAMETER CMServer
        CM site server
    .PARAMETER VerboseLogging
        If VerboseLogging is set to be $true, then detailed logging will be written
    .INPUTS
        None. You cannot pipe objects in.
    .OUTPUTS
        None. Does not generate any output.
    .EXAMPLE
        .\CreateApplication.ps1 -XMLDocument "c:\temp\Applications.xml" -Action "Development"
        Creates the application and collections for the development environment.
    .EXAMPLE
        .\CreateApplication.ps1 -XMLDocument "c:\temp\Applications.xml" -Action "Production"
        Moves the applications from development to production.
    .EXAMPLE
        .\CreateApplication.ps1 -XMLDocument "c:\temp\Applications.xml" -Action "Retired"
        Moves the Applications to the Retired folder.
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
    [bool]$UpdateOnlyDatedDrivers = $False, # Use this to exclude any drivers we already have updated on the system
    [bool]$Global:Debug = $True
)

# _SMSTSSiteCode = CHQ


#Import Modules
Remove-Module $PSScriptRoot\MODULE_Functions -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot\MODULE_Functions -Force -WarningAction SilentlyContinue

# Need to be able to seperate this out but for now......
$SCCMDistributionPoint = $SCCMServer

Try
{
    $Global:tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
    $tsvars = $tsenv.GetVariables()
    Write-Host "Fetching TS Environment"
}
Catch
{
    Write-Host "Not running in a task sequence."
}


If ($tsenv)
{
    Write-Host "Get TS Variables"

    If (-not $SCCMServer)
    {
        # $SCCMServer = "CM1.corp.contoso.com"
        $SCCMServer = $tsenv.Value("_SMSTSMP")

        # _SMSTSCHQ00005 = http://cm1.corp.contoso.com/sms_dp_smspkg$/chq00005 
        # Maybe use this for the DP?

        #$SCCMDistributionPoint = "CM1.corp.contoso.com"

        $SCCMDistributionPoint = $tsenv.Value("_SMSTSMP")
    }

    Try
    {
        $TSVar_Path = $tsenv.Value("TSVar_Path")
    }
    Catch
    {
        Write-Host "Could not get TSVar_Path."
    }

    Try
    {
        $TSVar_SCCMServerDB = $tsenv.Value("TSVar_SCCMServerDB")
    }
    Catch
    {
        Write-Host "Could not get TSVar_SCCMServerDB."
    }

    Try
    {
        $TSVar_InstallDrivers = $tsenv.Value("TSVar_InstallDrivers")
    }
    Catch
    {
        Write-Host "Could not get TSVar_InstallDrivers."
    }

    Try
    {
        $TSVar_Categories = $tsenv.Value("TSVar_Categories")
    }
    Catch
    {
        # Do nothing
    }

    Try
    {
        $TSVar_DownloadDrivers = $tsenv.Value("TSVar_DownloadDrivers")
    }
    Catch
    {
        # Do nothing
    }

    Try
    {
        $TSVar_FindAllDrivers = $tsenv.Value("TSVar_FindAllDrivers")
    }
    Catch
    {
        # Do nothing
    }

    Try
    {
        $TSVar_HardwareMustBePresent = $tsenv.Value("TSVar_HardwareMustBePresent")
    }
    Catch
    {
        # Do nothing
    }

    Try
    {
        $TSVar_UpdateOnlyDatedDrivers = $tsenv.Value("TSVar_UpdateOnlyDatedDrivers")
    }
    Catch
    {
        # Do nothing
    }

    Try
    {
        $TSVar_Debug = $tsenv.Value("TSVar_Debug")
    }
    Catch
    {
        # Do nothing
    }

    If ($TSVar_Path)
    {
        $Path = $TSVar_Path
    }
    If ($TSVar_SCCMServerDB)
    {
        $SCCMServerDB = $TSVar_SCCMServerDB
    }
    If ($TSVar_Categories)
    {
        $Categories = $TSVar_Categories
    }
    If ($TSVar_InstallDrivers)
    {
       $InstallDrivers = [bool]$TSVar_InstallDrivers
    }
    If ($TSVar_DownloadDrivers)
    {
       $DownloadDrivers = [bool]$TSVar_DownloadDrivers
    }
    If ($TSVar_FindAllDrivers)
    {
       $FindAllDrivers = [bool]$TSVar_FindAllDrivers
    }
    If ($TSVar_HardwareMustBePresent)
    {
       $HardwareMustBePresent = [bool]$TSVar_HardwareMustBePresent
    }
    If ($TSVar_UpdateOnlyDatedDrivers)
    {
       $UpdateOnlyDatedDrivers = [bool]$TSVar_UpdateOnlyDatedDrivers
    }
    If ($TSVar_UpdateOnlyDatedDrivers)
    {
       $UpdateOnlyDatedDrivers = [bool]$TSVar_UpdateOnlyDatedDrivers
    }
    If ($TSVar_Debug)
    {
       $Debug = [bool]$TSVar_Debug
    }
}

If (-not $Path)
{
    Write-Host "Missing critical information:"
    Write-Host "Path: $Path"
    Write-Host "Exiting...."
    LogIt -message ("Missing critical information:") -component "Main()" -type "Error" -LogFile $LogFile
    LogIt -message ("Path: "+$Path) -component "Main()" -type "Error" -LogFile $LogFile
    LogIt -message ("Exiting....") -component "Main()" -type "Error" -LogFile $LogFile
    Exit 1
}
ElseIf (-not $SCCMServer)
{
    Write-Host "Missing critical information:"
    Write-Host "SCCMServer: $SCCMServer"
    Write-Host "Exiting...."
    LogIt -message ("Missing critical information:") -component "Main()" -type "Error" -LogFile $LogFile
    LogIt -message ("SCCMServer: "+$SCCMServer) -component "Main()" -type "Error" -LogFile $LogFile
    LogIt -message ("Exiting....") -component "Main()" -type "Error" -LogFile $LogFile
    Exit 1
}
ElseIf (-not $SCCMServerDB)
{
    Write-Host "Missing critical information:"
    Write-Host "SCCMServerDB: $SCCMServerDB"
    Write-Host "Exiting...."
    LogIt -message ("Missing critical information:") -component "Main()" -type "Error" -LogFile $LogFile
    LogIt -message ("SCCMServerDB: "+$SCCMServerDB) -component "Main()" -type "Error" -LogFile $LogFile
    LogIt -message ("Exiting....") -component "Main()" -type "Error" -LogFile $LogFile
    Exit 1
}


If(-not (test-path $Path))
{
      New-Item -ItemType Directory -Force -Path $Path
}

$Global:LogFile = Join-Path ($Path) 'AutoApplyDrivers.log' 

LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component "Main()" -type "Info" -LogFile $LogFile


If (-not $Credential -and $tsenv)
{
    $TSUsernameVar = $tsvars | Where-Object {$_ -like "_SMSTSReserved1*"}
    $TSPasswordVar = $tsvars | Where-Object {$_ -like "_SMSTSReserved2*"}


    If ($TSUsernameVar.Count -ge 1)
    {
        $username = $tsenv.Value($TSUsernameVar)
        $password = $tsenv.Value($TSPasswordVar) | ConvertTo-SecureString -asPlainText -Force

        LogIt -message ("Running as: "+$username) -component "Main()" -type "Info" -LogFile $LogFile

        $Credential = New-Object System.Management.Automation.PSCredential($username,$password)
        $Credential | Add-Member -name "ClearTextPassword" -type NoteProperty -value $tsenv.Value($TSPasswordVar)

        If ($username.Count -gt 1)
        {
            LogIt -message ("More than one username found.  Using first found credential.") -component "Main()" -type "Warning" -LogFile $LogFile
        }
    }
    Else
    {
        LogIt -message ("No task sequence variable for username found. Running in current context.") -component "Main()" -type "Warning" -LogFile $LogFile
    }
}
ElseIf(-not $Credential -and $Debug)
{
    LogIt -message ("Fetching credentials from user.") -component "Main()" -type "Info" -LogFile $LogFile
    #$Credential = Get-Credential
    #LogIt -message ("Running as: "+$Credential.UserName.ToString()) -component "Main()" -type "Info" -LogFile $LogFile
}
ElseIf(-not $Credential)
{
    LogIt -message ("Running under current credentials.") -component "Main()" -type "Info" -LogFile $LogFile
}
Else
{
    LogIt -message ("Running as: "+$Credential.UserName.ToString()) -component "Main()" -type "Info" -LogFile $LogFile
}

LogIt -message ("Starting execution....") -component "Main()" -type "Info" -LogFile $LogFile

# Need to get local drivers and build out the XML
LogIt -message ("Generating XML from list of devices on the device") -component "Main()" -type "Info" -LogFile $LogFile


$hwidtable = New-Object System.Data.DataTable
$hwidtable.Columns.Add("FriendlyName","string") | Out-Null
$hwidtable.Columns.Add("HardwareID","string") | Out-Null

$xml = "<DriverCatalogRequest>"

$CategoryInstance_UniqueIDs = @()

If ($Categories -and $SCCMServer)
{
    LogIt -message ("Querying driver category information.") -component "Main()" -type "Info" -LogFile $LogFile


    $xml += "<Categories>"

    # WMI query: SELECT * FROM SMS_CategoryInstance where CategoryTypeName = 'DriverCategories'
    # https://cm1/AdminService/wmi/CategoryInstance?$filter=CategoryTypeName
    ForEach ($Category in $Categories)
    {
        If ($CategoryWildCard)
        {
            $SqlQuery = "SELECT CategoryInstance_UniqueID FROM v_CategoryInfo WHERE CategoryTypeName = 'DriverCategories' AND IsDeleted = '0' AND CategoryInstanceName LIKE '%$Category%'"
        }
        Else
        {
            $SqlQuery = "SELECT CategoryInstance_UniqueID FROM v_CategoryInfo WHERE CategoryTypeName = 'DriverCategories' AND IsDeleted = '0' AND CategoryInstanceName = '$Category'"
        }

        if ($Credential)
        {
            $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery -Credential $Credential
        }
        else
        {
            $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery
        }

        $xml += "<Category>"+$return[1].Rows[0][0].ToString()+"</Category>"
    }

    $xml += "</Categories>"
}
ElseIf (-not $SCCMServer)
{
    LogIt -message ("Nothing passed in for the Database Server. Running locally only for gathering/testing purposes.") -component "Main()" -type "Warning" -LogFile $LogFile
}

$xml += "<Devices>"

Try
{
    $localdevices = Get-PnpDevice

    If ($HardwareMustBePresent)
    {
        $localdevices = $localdevices | Where-Object {$_.Present}
    }

    ForEach ($_ in $localdevices){
    
        # Find out all our use cases where we want to skip this device
        If (-not $_)
        {
            Continue
        }

        $xml += "<Device>"
        $xml += "<!-- "+$_.Manufacturer+" | "+$_.FriendlyName+" -->"

        ForEach ($__ in $_.HardwareID)
        {
            If ($__.ToString() -like "*\*")
            {
                $xml += "<HwId>"+$__.ToString()+"</HwId>"
            }
            Else
            {
                Continue
            }

            If ($__.ToString() -like "*{*")
            {
                # Fixes an issue where items with curly braces seem to not match unless we strip the first part.
                # Edge case but vOv
                $xml += "<HwId>"+$__.Split("\")[1].ToString()+"</HwId>"
            }
        
        }

        $xml += "</Device>"

    }
}
Catch
{
    LogIt -message ("Cannot get local hardware devices.") -component "Main()" -type "Error" -LogFile $LogFile
    LogIt -message ("Continuing with fake hardware list.") -component "Main()" -type "Warning" -LogFile $LogFile
    $xml += "<Device><!-- Microsoft | Microsoft XPS Document Writer (redirected 2) --><HwId>PRINTENUM\LocalPrintQueue</HwId></Device><Device><!-- Microsoft | Microsoft Print to PDF (redirected 2) --><HwId>PRINTENUM\LocalPrintQueue</HwId></Device><Device><!-- Microsoft | Microsoft Print to PDF --><HwId>PRINTENUM\{084f01fa-e634-4d77-83ee-074817c03581}</HwId><HwId>{084f01fa-e634-4d77-83ee-074817c03581}</HwId><HwId>PRINTENUM\LocalPrintQueue</HwId></Device><Device><!-- Microsoft | Microsoft XPS Document Writer --><HwId>PRINTENUM\{0f4130dd-19c7-7ab6-99a1-980f03b2ee4e}</HwId><HwId>{0f4130dd-19c7-7ab6-99a1-980f03b2ee4e}</HwId><HwId>PRINTENUM\LocalPrintQueue</HwId></Device>"
}

$xml = $xml+"</Devices></DriverCatalogRequest>"
$xml = $xml.Replace("&","&amp;")

$xml | Format-Xml | Out-File -FilePath (Join-Path -Path $Path -ChildPath "Drivers.xml")

$localdevices | Sort-Object | Format-Table -Wrap -AutoSize -Property Class, FriendlyName, InstanceId | Out-File -FilePath (Join-Path -Path $Path -ChildPath "PnPDevices.log")

If (-not $SCCMServer)
{
    LogIt -message ("Cannot continue as no SCCM/DB server specified. Exiting...") -component "Main()" -type "Warning" -LogFile $LogFile
    Exit 1
}

# Run the drivers against the stored procs to find matches
LogIt -message ("Querying MP for list of matching drivers.") -component "Main()" -type "Info" -LogFile $LogFile


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
    LogIt -message ("No valid drivers found.  Exiting.") -component "Main()" -type "Warning" -LogFile $LogFile
    Exit 119
}

LogIt -message ("Found the following drivers (CI_ID):") -component "Main()" -type "Debug" -LogFile $LogFile
LogIt -message ("$drivers.CI_ID") -component "Main()" -type "Debug" -LogFile $LogFile

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


LogIt -message ("Querying additional driver information for matching drivers.") -component "Main()" -type "Info" -LogFile $LogFile

$SqlQuery = "SELECT CI_ID, DriverType, DriverINFFile, DriverDate, DriverVersion, DriverClass, DriverProvider, DriverSigned, DriverBootCritical FROM v_CI_DriversCIs WHERE CI_ID IN $CI_ID_list"

if ($Credential)
{
    $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery -Credential $Credential
}
else
{
    $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery
}

$return | Out-File -Append -FilePath (Join-Path -Path $Path -ChildPath "v_CI_DriversCIs.log")

Try
{
    $DriverListAll = $return[1] | Sort-Object -Property @{Expression = "DriverINFFile"; Descending = $False}, @{Expression = "DriverDate"; Descending = $True}, @{Expression = "DriverVersion"; Descending = $True} 
    $DriverList = @()
}
Catch
{
    LogIt -message ("Unable to find valid driver information. Exiting...") -component "Main()" -type "Error" -LogFile $LogFile
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
            LogIt -message ("Newer driver already exists, skipping.") -component "Main()" -type "Debug" -LogFile $LogFile
        }
        Else
        {
            LogIt -message ("Adding driver to list." ) -component "Main()" -type "Debug" -LogFile $LogFile
            $DriverList += $_
        }
    }
}


If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] “Administrator”))
{
    $OnlineDrivers = Get-WindowsDriver -Online -All
    $DriverListFinal = @()

    # Remove drivers that don't need to be updated
    ForEach ($Driver in $DriverList)
    {
        # We have to do this in two steps because the date should ALWAYS win even if the version is newer.
        If (($OnlineDrivers | Where-Object {$_.ClassName -eq $DriverList[0].DriverClass -and $_.ProviderName -eq $DriverList[0].DriverProvider -and $_.Driver -eq $DriverList[0].DriverINFFile -and $_.Date -lt $DriverList[0].DriverDate}).Count -gt 0)
        {

            LogIt -message ("Found a newer driver, add it to the list.") -component "Main()" -type "Debug" -LogFile $LogFile
            $DriverListFinal += $Driver
            Continue
        }
        ElseIf (($OnlineDrivers | Where-Object {$_.ClassName -eq $DriverList[0].DriverClass -and $_.ProviderName -eq $DriverList[0].DriverProvider -and $_.Driver -eq $DriverList[0].DriverINFFile -and [Version]$_.Version -lt [Version]$DriverList[0].DriverVersion -and $_.Date -lt $DriverList[0].DriverDate}).Count -gt 0)
        {
            LogIt -message ("Found a newer driver, add it to the list.") -component "Main()" -type "Debug" -LogFile $LogFile
            $DriverListFinal += $Driver
            Continue
        }
        Else
        {
            LogIt -message ("No newer driver found, skip!") -component "Main()" -type "Debug" -LogFile $LogFile
            Continue
        }
    }
}
Else
{
    $DriverListFinal = "Not running as administrator.  Unable to check SCCM drivers against local drivers to see if the local drivers are newer than targetted drivers."
    LogIt -message ($DriverListFinal) -component "Main()" -type "Warning" -LogFile $LogFile
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

# Parse CI_ID against v_DriverContentToPackage to get the Content_UniqueID
LogIt -message ("Parsing v_DriverContentToPackage to map drivers to content download location") -component "Main()" -type "Info" -LogFile $LogFile

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

If ($DownloadDrivers)
{
    LogIt -message ("Downloading drivers from distribution point") -component "Main()" -type "Info" -LogFile $LogFile

    If ($Content_UniqueIDs)
    {
        # Download drivers
        # TODO: Add ability to select DP

        LogIt -message ("Parsing Found Drivers: "+$Content_UniqueIDs) -component "Main()" -type "Debug" -LogFile $LogFile

        ForEach ($Content_UniqueID in $Content_UniqueIDs)
        {
            LogIt -message ("Parsing Content_UniqueID: "+$Content_UniqueID) -component "Main()" -type "Debug" -LogFile $LogFile

            If ($Credential)
            {
                LogIt -message ("Calling Download-Drivers with credentials") -component "Main()" -type "Debug" -LogFile $LogFile
                Download-Drivers -P $Path -DriverGUID $Content_UniqueID -SCCMDistributionPoint $SCCMDistributionPoint -Credential $Credential
            }
            else
            {
                LogIt -message ("Calling Download-Drivers without credentials") -component "Main()" -type "Debug" -LogFile $LogFile
                Download-Drivers -P $Path -DriverGUID $Content_UniqueID -SCCMDistributionPoint $SCCMDistributionPoint
            }
        }
    }
    Else
    {
        LogIt -message ("No drivers found to download.") -component "Main()" -type "Warning" -LogFile $LogFile
    }
}
Else
{
    LogIt -message ("Skipping downloading of drivers.") -component "Main()" -type "Warning" -LogFile $LogFile
}


# Inject the drivers into the OS

if ($InstallDrivers)
{
    If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] “Administrator”))
    {

        LogIt -message ("Apply downloaded drivers to online operating system.") -component "Main()" -type "Info" -LogFile $LogFile

        Install-Drivers -Path $Path
    }
    Else
    {
        LogIt -message ("Not running as administrator.  Unable to install drivers.") -component "Main()" -type "Error" -LogFile $LogFile
    }
}
else
{
    LogIt -message ("Skipping installation of drivers.") -component "Main()" -type "Warning" -LogFile $LogFile
}


LogIt -message ("Script Execution Complete") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile

# :beer: