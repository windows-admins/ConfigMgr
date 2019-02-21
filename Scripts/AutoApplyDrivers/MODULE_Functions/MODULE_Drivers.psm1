

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
