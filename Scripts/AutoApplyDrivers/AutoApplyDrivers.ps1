﻿
function Get-SqlCommand
{
	[OutputType([Microsoft.SqlServer.Management.Smo.StoredProcedure])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

        [Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

			if ($PSBoundParameters.ContainsKey('Credential'))
			{
			    $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database -Credential $Credential
            }
            else
            {
                $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database
            }

			$sqlConnection = New-SqlConnection -ConnectionString $connectionString

			$serverInstance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $sqlConnection
			$serverInstance.Databases[$Database].StoredProcedures
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function New-SqlConnectionString
{
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			#region Build the connection string. Doing this allows for easy addition or removal of attributes
			$connectionStringElements = [ordered]@{
				Server = "tcp:$ServerName,1433"
				'Initial Catalog' = $Database
				'Persist Security Info' = 'False'
			}
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$connectionStringElements.'User ID' = $Credential.UserName
				$connectionStringElements.'Password' = $Credential.GetNetworkCredential().Password 
			}
			$connectionStringElements += @{
				'MultipleActiveResultSets' = 'False'
				'Encrypt' = 'False'
				'TrustServerCertificate' = 'True'
				'Connection Timeout' = '30'
                'trusted_connection' = 'False'
                'Integrated Security' = 'True'
            }

			$connectionString = ''
			@($connectionStringElements.GetEnumerator()).foreach({
				$connectionString += "$($_.Key)=$($_.Value);"
			})
			return $connectionString
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function New-SqlConnection
{
	[OutputType([System.Data.SqlClient.SqlConnection])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ConnectionString	
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
			$SqlConnection.ConnectionString = $connectionString
			return $SqlConnection
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Invoke-SqlCommand
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[string]$Parameter,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            if ($PSBoundParameters.ContainsKey('Credential'))
			{
			    $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database -Credential $Credential
            }
            else
            {
                $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database 
            }

			$SqlConnection = New-SqlConnection -ConnectionString $connectionString

			$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
			$SqlCmd.CommandText = $Name
			$SqlCmd.Connection = $SqlConnection

            if ($Parameter)
            {
                $SqlCmd.CommandType=[System.Data.CommandType]’StoredProcedure’
                $SqlCmd.Parameters.AddWithValue("@xtext", $Parameter) | Out-Null
            }

            # Write-Host $SqlCmd.Parameters
			$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
			$SqlAdapter.SelectCommand = $SqlCmd
			$DataSet = New-Object System.Data.DataSet
			$SqlAdapter.Fill($DataSet)
            # Write-Host $SqlAdapter
            Return $DataSet.Tables
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Download-Drivers
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Path,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$DriverGUID,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$SCCMDistributionPoint,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            Write-Host "Download Drivers from DP"
            if (-not (Test-Path -Path $Path))
            {
                Write-Host "Driver download path does not exist.  Exiting."
                Exit 3
            }

            #$DriverGUID = "1665CB2C-8B4F-4404-B4E5-94B527978D05"

            $driverpath = Join-Path -Path $Path -ChildPath $DriverGUID

            if (Test-Path -Path $driverpath)
            {
                Write-Host "Driver folder exists, nuke."
                Remove-Item $driverpath -Force -Recurse
            }

            New-Item -ItemType directory -Path $driverpath

            Write-Host "Getting list of drivers from IIS"

            try 
            {
                If ($Credential)
                {
                    $request = Invoke-WebRequest http://$SCCMDistributionPoint/SMS_DP_SMSPKG`$/$DriverGUID -UseBasicParsing -Credential $Credential -TimeoutSec 180 -ErrorAction:Stop
                }
                Else
                {
                    $request = Invoke-WebRequest http://$SCCMDistributionPoint/SMS_DP_SMSPKG`$/$DriverGUID -UseBasicParsing -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop
                }
            }
            catch
            {
                # TODO: Output this information
                Write-Host $_.Exception
                Write-Host $_.ErrorDetails.ToSTring()
            }

            $links = $request.Links.outerHTML

            foreach ($link in $links)
            {
                Write-Host "Downloading: $FileName"
                $URL = $link.Split("""")[1]

                #We can get different casing on this, use RegEx to handle that scenario
                $FileName = $URL -ireplace [regex]::Escape("http://$SCCMDistributionPoint/SMS_DP_SMSPKG$/$DriverGUID/"), ""
                $outfilepath = Join-Path -Path $driverpath -ChildPath $FileName

                try 
                {
                    If ($Credential)
                    {
                        $request = Invoke-WebRequest -Uri $URL -outfile $outfilepath -UseBasicParsing -Credential $Credential -TimeoutSec 180 -ErrorAction:Stop
                    }
                    Else
                    {
                        $request = Invoke-WebRequest -Uri $URL -outfile $outfilepath -UseBasicParsing -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop
                    }
                }
                catch
                {
                    # TODO: Output this information
                    Write-Host $_.Exception
                    Write-Host $_.ErrorDetails.ToSTring()
                }
            }
        }
        Catch
        {
            # Do things
        }
    }
}


function Install-Drivers
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$basepath
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            $installlist = Get-ChildItem -Path $basepath -Filter *.inf -r

            ForEach ($inf in $installlist)
            {
                Write-Host "Installing $inf.name"
                pnputil /add-driver $inf.FullName /subdirs /install | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "pnputil.log") -Append
            }
        }
        Catch
        {
            # Do things
        }
    }
}

function Write-Log
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Path,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Output,

		[ValidateNotNullOrEmpty()]
		#[binary]$WriteHost=$False,
        $WriteHost=$False,
        
		[string]$DebugLevel
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
        # Examples:
        # Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $LoggingWriteInfoHost -DebugLevel "Error"
        # Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $LoggingWriteInfoHost -DebugLevel "Warning"

		try
		{
            $Output | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")

            If($WriteHost)
            {
                If ($DebugLevel -eq "Error")
                {
                    Write-Host -ForegroundColor Red $Output
                }
                ElseIf ($DebugLevel -eq "Warning")
                {
                    Write-Host -ForegroundColor Yellow $Output
                }
                Else
                {
                    Write-Host $Output
                }
            }
        }
        Catch
        {
            Write-Host -ForegroundColor Red "Failed to execute function Write-Log"
        }
    }
}

function Format-Xml {
<#
.SYNOPSIS
Format the incoming object as the text of an XML document.
#>
    param(
        ## Text of an XML document.
        [Parameter(ValueFromPipeline = $true)]
        [string[]]$Text
    )

    begin {
        $data = New-Object System.Collections.ArrayList
    }
    process {
        [void] $data.Add($Text -join "`n")
    }
    end {
        $doc=New-Object System.Xml.XmlDataDocument
        $doc.LoadXml($data -join "`n")
        $sw=New-Object System.Io.Stringwriter
        $writer=New-Object System.Xml.XmlTextWriter($sw)
        $writer.Formatting = [System.Xml.Formatting]::Indented
        $doc.WriteContentTo($writer)
        $sw.ToString()
    }
}



#=========================================================================================================================================


#Definitions
$basepath = "c:\Temp\Drivers"

# Uncomment to use a specific set of credentials
$Credential = Get-Credential

$SCCMServer = "CM1.corp.contoso.com"
$SCCMDistributionPoint = "CM1.corp.contoso.com"
$SCCMServerDB = "ConfigMgr_CHQ"

$InstallDrivers = $False
$DownloadDrivers = $True
$FindAllDrivers = $False
$HardwareMustBePresent = $False
$UpdateOnlyDatedDrivers # Use this to exclude any drivers we already have updated on the system

#$Categories = @("9370","Test")
$Categories = @()
$CategoryWildCard = $True

$LoggingWriteInfoHost = $True
$LoggingWriteDebugHost = $True

$Debug = $False

Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $LoggingWriteInfoHost


# Need to get local drivers and build out the XML
Write-Log -Path $basepath -Output "Generating XML from list of devices on the device" -WriteHost $LoggingWriteInfoHost

$hwidtable = New-Object System.Data.DataTable
$hwidtable.Columns.Add("FriendlyName","string") | Out-Null
$hwidtable.Columns.Add("HardwareID","string") | Out-Null

$xml = "<DriverCatalogRequest>"

$CategoryInstance_UniqueIDs = @()

If ($Categories)
{
    Write-Log -Path $basepath -Output "Querying driver category information." -WriteHost $LoggingWriteInfoHost

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
Write-Log -Path $basepath -Output "Querying MP for list of matching drivers" -WriteHost $LoggingWriteInfoHost

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
    Write-Log -Path $basepath -Output "No valid drivers found.  Exiting." -WriteHost $LoggingWriteInfoHost
    Exit 119
}

# Write-Log -Path $basepath -Output "Found the following drivers:" -WriteHost $LoggingWriteDebugHost
# Write-Log -Path $basepath -Output "$drivers.CI_ID" -WriteHost $LoggingWriteDebugHost

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


Write-Log -Path $basepath -Output "Querying additional driver information for matching drivers." -WriteHost $LoggingWriteInfoHost

$SqlQuery = "SELECT CI_ID, DriverType, DriverINFFile, DriverDate, DriverVersion, DriverClass, DriverProvider, DriverSigned, DriverBootCritical FROM v_CI_DriversCIs WHERE CI_ID IN $CI_ID_list"

if ($Credential)
{
    $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery -Credential $Credential
}
else
{
    $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery
}


$DriverListAll = $return[1] | Sort-Object -Property @{Expression = "DriverINFFile"; Descending = $False}, @{Expression = "DriverDate"; Descending = $True}, @{Expression = "DriverVersion"; Descending = $True} 
$DriverList = @()

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
            if ($Debug){Write-Log -Path $basepath -Output "Newer driver already exists, skipping." -WriteHost $LoggingWriteDebugHost}
        }
        Else
        {
            if ($Debug){Write-Log -Path $basepath -Output "Adding driver to list." -WriteHost $LoggingWriteDebugHost}
            $DriverList += $_
        }
    }
}


$OnlineDrivers = Get-WindowsDriver -Online -All
$DriverListFinal = @()

# Remove drivers that don't need to be updated
ForEach ($Driver in $DriverList)
{
    If (($OnlineDrivers | Where-Object {$_.ClassName -eq $DriverList[0].DriverClass -and $_.ProviderName -eq $DriverList[0].DriverProvider -and $_.Driver -eq $DriverList[0].DriverINFFile -and $_.Version -eq $DriverList[0].DriverVersion -and $_.Date -eq $DriverList[0].DriverDate}).Count -gt 0)
    {
        # Found a matching driver, we can skip this one.
        Continue
    }
    Else
    {
        $DriverListFinal += $Driver
    }
}


"All drivers found:" | Out-String | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$DriverListAll | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"" | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"Targeted drivers:" | Out-String | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$DriverList | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"" | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"Non-updated drivers:" | Out-String | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$DriverListFinal | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")

If ($UpdateOnlyDatedDrivers)
{
    $DriverList = $DriverListFinal
}

# Parse CI_ID against v_DriverContentToPackage to get the Content_UniqueID
Write-Log -Path $basepath -Output "Parsing v_DriverContentToPackage to map drivers to content download location" -WriteHost $LoggingWriteDebugHost

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
    Write-Log -Path $basepath -Output "Downloading drivers from distribution point" -WriteHost $LoggingWriteInfoHost
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
    Write-Log -Path $basepath -Output "Apply downloaded drivers to online operating system." -WriteHost $LoggingWriteInfoHost

    Install-Drivers -driverbasepath $basepath
}
else
{
    Write-Log -Path $basepath -Output "Skipping installation of drivers" -WriteHost $LoggingWriteInfoHost
}

Write-Log -Path $basepath -Output "Script Execution Complete" -WriteHost $LoggingWriteInfoHost
Write-Log -Path $basepath -Output " " -WriteHost $LoggingWriteInfoHost
Write-Log -Path $basepath -Output " " -WriteHost $LoggingWriteInfoHost

# :beer: