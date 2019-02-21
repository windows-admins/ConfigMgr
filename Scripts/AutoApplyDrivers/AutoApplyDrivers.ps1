#Import Modules
Remove-Module $PSScriptRoot\MODULE_Functions -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot\MODULE_Functions -Force -WarningAction SilentlyContinue

$basepath = "c:\Temp\Drivers"
$Global:LogFile = Join-Path ($basepath) 'AutoApplyDrivers.log' 

LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component "Main()" -type "Info" -LogFile $LogFile

Try
{
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
    $tsvars = $tsenv.GetVariables()

}
Catch
{
    Write-Host "Not running in a task sequence."
}


If (-not $Credential -and $tsenv)
{
    $TSUsernameVar = $tsvars | Where-Object {$_ -like "_SMSTSReserved1*"}
    $TSPasswordVar = $tsvars | Where-Object {$_ -like "_SMSTSReserved2*"}


    If ($NAAUsername.Count -ge 1)
    {
        $username = $_SMSTSLogPath = $tsenv.Value($TSUsernameVar)
        $password = $_SMSTSLogPath = $tsenv.Value($TSPasswordVar) | ConvertTo-SecureString -asPlainText -Force

        $Credential = New-Object System.Management.Automation.PSCredential($username,$password)

        If ($NAAUsername.Count -gt 1)
        {
            Write-Host WARNING: More than one username found.  Using first found credential.
        }
    }
    Else
    {
        Write-Host No credentials found in task sequence variables, attempting to run under current credentials.
    }
}
ElseIf(-not $Credential -and $PromptForCredentials)
{
    $Credential = Get-Credential
}
Else
{
    Write-Host Running under current credentials.
}


#Definitions
$basepath = "c:\Temp\Drivers"

If (-not $SCCMServer -and $tsenv)
{
    # $SCCMServer = "CM1.corp.contoso.com"
    $SCCMServer = $tsenv.Value("_SMSTSMP")
}


# _SMSTSCHQ00005 = http://cm1.corp.contoso.com/sms_dp_smspkg$/chq00005 
# Maybe use this for the DP?

#$SCCMDistributionPoint = "CM1.corp.contoso.com"
If (-not $SCCMServer -and $tsenv)
{
    $SCCMDistributionPoint = $tsenv.Value("_SMSTSMP")
}


# _SMSTSSiteCode = CHQ
$SCCMServerDB = "ConfigMgr_CHQ"

$InstallDrivers = $False
$DownloadDrivers = $True
$FindAllDrivers = $False
$HardwareMustBePresent = $False
$UpdateOnlyDatedDrivers = $True # Use this to exclude any drivers we already have updated on the system

#$Categories = @("9370","Test")
$Categories = @()
$CategoryWildCard = $True

$LoggingWriteInfoHost = $True
$LoggingWriteDebugHost = $True

$Global:Debug = $False

LogIt -message ("Starting execution....") -component "Main()" -type "Info" -LogFile $LogFile

# Need to get local drivers and build out the XML
LogIt -message ("Generating XML from list of devices on the device") -component "Main()" -type "Info" -LogFile $LogFile


$hwidtable = New-Object System.Data.DataTable
$hwidtable.Columns.Add("FriendlyName","string") | Out-Null
$hwidtable.Columns.Add("HardwareID","string") | Out-Null

$xml = "<DriverCatalogRequest>"

$CategoryInstance_UniqueIDs = @()

If ($Categories)
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

$localdevices = Get-PnpDevice

$xml += "<Devices>"

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

$xml = $xml+"</Devices></DriverCatalogRequest>"
$xml = $xml.Replace("&","&amp;")

$xml | Format-Xml | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "Drivers.xml")

$localdevices | Sort-Object | Format-Table -Wrap -AutoSize -Property Class, FriendlyName, InstanceId | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "PnPDevices.log")

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




"All drivers found:" | Out-String | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$DriverListAll | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"" | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"Targeted drivers:" | Out-String | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$DriverList | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"" | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"Drivers Newer than Current:" | Out-String | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$DriverListFinal | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")


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
    # Download drivers
    # TODO: Add ability to select DP
    ForEach ($Content_UniqueID in $Content_UniqueIDs)
    {
        If ($Credential)
        {
            Download-Drivers -P $basepath -DriverGUID $Content_UniqueID -SCCMDistributionPoint $SCCMDistributionPoint -Credential $Credential
        }
        else
        {
            Download-Drivers -P $basepath -DriverGUID $Content_UniqueID -SCCMDistributionPoint $SCCMDistributionPoint
        }
    }
}


# Inject the drivers into the OS

if ($InstallDrivers)
{
    If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] “Administrator”))
    {

        LogIt -message ("Apply downloaded drivers to online operating system.") -component "Main()" -type "Info" -LogFile $LogFile

        Install-Drivers -driverbasepath $basepath
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