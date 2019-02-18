
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
		[string]$basepath,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$DriverGUID,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$SCCMServer
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
            if (-not (Test-Path -Path $basepath))
            {
                Write-Host "Driver download path does not exist.  Exiting."
                Exit 3
            }

            #$DriverGUID = "1665CB2C-8B4F-4404-B4E5-94B527978D05"

            $driverpath = Join-Path -Path $basepath -ChildPath $DriverGUID

            if (Test-Path -Path $driverpath)
            {
                Write-Host "Driver folder exists, nuke."
                Remove-Item $driverpath -Force -Recurse
            }

            New-Item -ItemType directory -Path $driverpath

            Write-Host "Getting list of drivers from IIS"

            $request = Invoke-WebRequest http://$SCCMServer/SMS_DP_SMSPKG`$/$DriverGUID -UseBasicParsing
            $links = $request.Links.outerHTML

            foreach ($link in $links)
            {
                $URL = $link.Split("""")[1]
                $FileName = $URL.Replace("http://$SCCMServer/SMS_DP_SMSPKG$/$DriverGUID/","")
                $driverpath = Join-Path -Path $basepath -ChildPath $DriverGUID
                $outfilepath = Join-Path -Path $driverpath -ChildPath $FileName

                Write-Host "Downloading: $FileName"
                Invoke-Webrequest -uri $URL -outfile $outfilepath
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
		try
		{
            #None of these work.  WHY?!?!?
            $Ouput | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            "$Ouput" | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            $Ouput | Out-String | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            $Ouput | Write-Output | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            "$Ouput" | Out-String | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            "$Ouput" | Write-Output | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            $Ouput | Out-String | Write-Output | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")

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





#=========================================================================================================================================


#Definitions
$basepath = "c:\Temp\Drivers"

# Uncomment to use a specific set of credentials
$Credential = Get-Credential

#$SCCMServer = "192.168.0.108"
$SCCMServer = "169.254.39.133"
$SCCMServerDB = "ConfigMgr_CHQ"

$InstallDrivers = $False
$DownloadDrivers = $False
$FindAllDrivers = $False

$LoggingWriteHost = $True

Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $LoggingWriteHost -DebugLevel "Error"

Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $LoggingWriteHost -DebugLevel "Warning"

Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $LoggingWriteHost

Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $False


# Need to get local drivers and build out the XML
Write-Host "Generating XML from list of devices on the device"

$hwidtable = New-Object System.Data.DataTable
$hwidtable.Columns.Add("FriendlyName","string") | Out-Null
$hwidtable.Columns.Add("HardwareID","string") | Out-Null

$xml = "<DriverCatalogRequest><Devices><Device>"

$localdevices = Get-PnpDevice

ForEach ($localdevicearray in $localdevices){
    ForEach ($localdevice in $localdevicearray.HardwareID){
        if (-not $localdevice){
            Write-Host "Hardware ID is null, skip."
            Continue
        }

        If ($localdevice -like "*\*"){
            $hwidrow = $hwidtable.NewRow()
            $hwidrow.FriendlyName = $localdevicearray.FriendlyName
            $hwidrow.HardwareID = $localdevice
            $hwidtable.Rows.Add($hwidrow)
        }
        Else{
            # Write-Host "Skipping $localdevice"
            Continue
        }
    }
}

ForEach ($temphwid in ($hwidtable.HardwareID | Sort-Object | Get-Unique)){
    $xml = $xml+"<HwId>$temphwid</HwId>"
}

$xml = $xml+"</Device></Devices></DriverCatalogRequest>"

$xml = $xml.Replace("&","&amp;")


# Example XML structure
# $xml = "<DriverCatalogRequest><Devices><Device><HwId>PCI\VEN_168C&amp;DEV_003E&amp;SUBSYS_080711AD&amp;REV_32</HwId><HwId>PCI\VEN_8086&amp;DEV_34F0&amp;SUBSYS_15511A56</HwId></Device></Devices></DriverCatalogRequest>"
# $xml = "<DriverCatalogRequest><Devices><Device><HwId>USB\VID_0BDA&amp;PID_58F4&amp;MI_00</HwId></Device></Devices></DriverCatalogRequest>"

# Example Category XML structure
#<Categories><Category>DriverCategories:8dba4f57-c50e-40ec-9ce9-adeb7d052216</Category></Categories>


$hwidtable | Sort-Object | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "PnPDevices.log")

# Run the drivers against the stored procs to find matches
Write-Host "Running Stored Proc to find drivers that apply to devices on this device"

if ($Credential)
{
    $drivers = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name MP_MatchDrivers -Parameter $xml -Credential $Credential
}
else
{
    $drivers = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name MP_MatchDrivers -Parameter $xml
}
Write-Host "Found the following drivers:"
Write-Host $drivers.CI_ID

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

$SqlQuery = "SELECT CI_ID, DriverType, DriverINFFile, DriverDate, DriverVersion, DriverClass, DriverProvider, DriverSigned, DriverBootCritical FROM v_CI_DriversCIs WHERE CI_ID IN $CI_ID_list"

if ($Credential)
{
    $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery -Credential $Credential
}
else
{
    $return = Invoke-SqlCommand -ServerName $SCCMServer -Database $SCCMServerDB -Name $SqlQuery
}


$return = $return | Sort-Object
$DriverList = @()

ForEach ($obj in $return[1])
{
    If ($FindAllDrivers)
    {
        $DriverList += $obj
    }
    Else
    {
        If (($DriverList.DriverINFFile -contains $obj.DriverINFFile) -and ($DriverList.DriverClass -contains $obj.DriverClass) -and ($DriverList.DriverProvider -contains $obj.DriverProvider))
        {
            # Write-Host "Skip!"
        }
        Else
        {
            # Write-Host "Adding to driver list"
            $DriverList += $obj
        }
    }
}

"All drivers found:" | Out-String | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$return[1] | Sort-Object | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"" | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"Targeted drivers:" | Out-String | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$DriverList | Sort-Object | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")


write-host "Pause"



# Parse CI_ID against v_DriverContentToPackage to get the Content_UniqueID
Write-Host "Parsing v_DriverContentToPackage to map drivers to content download location"

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
    # Download drivers
    ForEach ($Content_UniqueID in $Content_UniqueIDs)
    {
        Download-Drivers -driverbasepath $basepath -DriverGUID $Content_UniqueID -SCCMServer $SCCMServer
    }
}


# Inject the drivers into the OS

if ($InstallDrivers)
{
    Write-Host "Apply downloaded drivers to online operating system."

    Install-Drivers -driverbasepath $basepath
}
else
{
    Write-Host "Skipping installation of drivers"
}


Write-Host "Done"
# :beer: