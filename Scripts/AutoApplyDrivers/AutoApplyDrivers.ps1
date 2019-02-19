
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
		[string]$Path,

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

            $request = Invoke-WebRequest http://$SCCMServer/SMS_DP_SMSPKG`$/$DriverGUID -UseBasicParsing
            $links = $request.Links.outerHTML

            foreach ($link in $links)
            {
                Write-Host "Downloading: $FileName"
                $URL = $link.Split("""")[1]
                $FileName = $URL.Replace("http://$SCCMServer/SMS_DP_SMSPKG$/$DriverGUID/","")
                $outfilepath = Join-Path -Path $driverpath -ChildPath $FileName

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
        # Examples:
        # Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $LoggingWriteInfoHost -DebugLevel "Error"
        # Write-Log -Path $basepath -Output "Starting execution...." -WriteHost $LoggingWriteInfoHost -DebugLevel "Warning"

		try
		{
            #None of these work.  WHY?!?!?
            # $Ouput | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            # "$Ouput" | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            # $Ouput | Out-String | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            # $Ouput | Write-Output | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            # "$Ouput" | Out-String | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            # "$Ouput" | Write-Output | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")
            # $Ouput | Out-String | Write-Output | Out-File -Append -Encoding string -Force -FilePath (Join-Path -Path $Path -ChildPath "AutoApplyDrivers.log")

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

$SCCMServer = "169.254.39.133"
$SCCMServerDB = "ConfigMgr_CHQ"

$InstallDrivers = $False
$DownloadDrivers = $True
$FindAllDrivers = $False

$Categories = @("9370")
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

ForEach ($localdevicearray in $localdevices){
    ForEach ($localdevice in $localdevicearray.HardwareID){
        if (-not $localdevice){
            if ($Debug){Write-Log -Path $basepath -Output "Hardware ID is null, skip." -WriteHost $LoggingWriteDebugHost}
            Continue
        }

        If ($localdevice -like "*\*"){
            if ($Debug){Write-Log -Path $basepath -Output "Adding hardware to list." -WriteHost $LoggingWriteDebugHost}
            $hwidrow = $hwidtable.NewRow()
            $hwidrow.FriendlyName = $localdevicearray.FriendlyName
            $hwidrow.HardwareID = $localdevice
            $hwidtable.Rows.Add($hwidrow)
        }
        Else{
            if ($Debug){Write-Log -Path $basepath -Output "Skipping $localdevice" -WriteHost $LoggingWriteDebugHost}
            Continue
        }
    }
}

$xml += "<Devices>"

ForEach ($_ in ($hwidtable.FriendlyName | Get-Unique))
{
    $xml += "<Device>"
    $xml += "<!-- $_ -->"

    $HardwareID = $hwidtable | Where FriendlyName -like $_

    ForEach ($_ in $HardwareID)
    {
        $xml += "<HwId>"+$_.HardwareID.ToString()+"</HwId>"
    }

    $xml += "</Device>"
}

$xml = $xml+"</Devices></DriverCatalogRequest>"
$xml = $xml.Replace("&","&amp;")

$xml | Format-Xml | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "Drivers.xml")


$hwidtable | Sort-Object | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "PnPDevices.log")

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
            if ($Debug){Write-Log -Path $basepath -Output "Newer driver already exists, skipping." -WriteHost $LoggingWriteDebugHost}
        }
        Else
        {
            if ($Debug){Write-Log -Path $basepath -Output "Adding driver to list." -WriteHost $LoggingWriteDebugHost}
            $DriverList += $obj
        }
    }
}

"All drivers found:" | Out-String | Out-File -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$return[1] | Sort-Object | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"" | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
"Targeted drivers:" | Out-String | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")
$DriverList | Sort-Object | Format-Table | Out-File -Append -FilePath (Join-Path -Path $basepath -ChildPath "SCCMDrivers.log")



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
        Download-Drivers -P $basepath -DriverGUID $Content_UniqueID -SCCMServer $SCCMServer
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