

function Install-Drivers
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Path
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            $installlist = Get-ChildItem -Path $Path -Filter *.inf -r

            ForEach ($inf in $installlist)
            {
                Write-Host "Installing $inf.name"
                pnputil /add-driver $inf.FullName /subdirs /install | Out-File -FilePath (Join-Path -Path $Path -ChildPath "pnputil.log") -Append
            }
        }
        Catch
        {
            # Do things
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
		[pscredential]$Credential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [bool]$HTTPS
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
        LogIt -message ("Getting list of drivers from IIS") -component "Main()" -type "Info" -LogFile $LogFile
        LogIt -message ("Path: "+$Path) -component "Main()" -type "Debug" -LogFile $LogFile
        LogIt -message ("DriverGUID: "+$DriverGUID) -component "Main()" -type "Debug" -LogFile $LogFile
        LogIt -message ("SCCMDistributionPoint: "+$SCCMDistributionPoint) -component "Main()" -type "Debug" -LogFile $LogFile
        LogIt -message ("Credential: "+($Credential.UserName.ToString())) -component "Main()" -type "Debug" -LogFile $LogFile
		try
		{
            if (-not (Test-Path -Path $Path))
            {
                LogIt -message ("Driver download path does not exist.  Exiting...") -component "Main()" -type "Error" -LogFile $LogFile
                Exit 3
            }

            #$DriverGUID = "1665CB2C-8B4F-4404-B4E5-94B527978D05"

            $driverpath = Join-Path -Path $Path -ChildPath $DriverGUID

            if (Test-Path -Path $driverpath)
            {
                LogIt -message ("Driver folder exists, nuking folder from orbit.") -component "Main()" -type "Warning" -LogFile $LogFile
                Remove-Item $driverpath -Force -Recurse
            }

            New-Item -ItemType directory -Path $driverpath

            try 
            {
                LogIt -message ("Fetching: http://"+$SCCMDistributionPoint+"/SMS_DP_SMSPKG$/"+$DriverGUID) -component "Main()" -type "Debug" -LogFile $LogFile
                If ($Credential)
                {
                    LogIt -message ("Invoking web request with credentials") -component "Main()" -type "Debug" -LogFile $LogFile
                    If($HTTPS)
					{
                    	$request = Invoke-WebRequest https://$SCCMDistributionPoint/NOCERT_SMS_DP_SMSPKG`$/$DriverGUID -UseBasicParsing -Credential $Credential -TimeoutSec 180 -ErrorAction:Stop
                    }
					Else
					{
                    	$request = Invoke-WebRequest http://$SCCMDistributionPoint/SMS_DP_SMSPKG`$/$DriverGUID -UseBasicParsing -Credential $Credential -TimeoutSec 180 -ErrorAction:Stop
                    }
                }
                Else
                {
                    LogIt -message ("Invoking web request without credentials") -component "Main()" -type "Debug" -LogFile $LogFile
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
                If($HTTPS)
				{
                    $URL = $URL.replace("http://","https://")
                	$FileName = $URL -ireplace [regex]::Escape("https://$SCCMDistributionPoint/NOCERT_SMS_DP_SMSPKG$/$DriverGUID/"), ""
                }
				Else
				{
                	$FileName = $URL -ireplace [regex]::Escape("http://$SCCMDistributionPoint/SMS_DP_SMSPKG$/$DriverGUID/"), ""
				}

				$outfilepath = Join-Path -Path $driverpath -ChildPath $FileName

                try 
                {
                    LogIt -message ("Fetching: "+$URL) -component "Main()" -type "Debug" -LogFile $LogFile
                    If ($Credential)
                    {
                        LogIt -message ("Invoking web request with credentials") -component "Main()" -type "Debug" -LogFile $LogFile
                        $request = Invoke-WebRequest -Uri $URL -outfile $outfilepath -UseBasicParsing -Credential $Credential -TimeoutSec 180 -ErrorAction:Stop
                    }
                    Else
                    {
                        LogIt -message ("Invoking web request without credentials") -component "Main()" -type "Debug" -LogFile $LogFile
                        $request = Invoke-WebRequest -Uri $URL -outfile $outfilepath -UseBasicParsing -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop
                    }
                }
                catch
                {
                    LogIt -message ("Failed to download drivers") -component "Main()" -type "Error" -LogFile $LogFile
                    LogIt -message ($_.Exception) -component "Main()" -type "Error" -LogFile $LogFile
                    LogIt -message ($_.ErrorDetails.ToSTring()) -component "Main()" -type "Error" -LogFile $LogFile
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
