Write-Host "Loading: MODULE_Drivers"

function Install-Drivers
{
	[CmdletBinding()]
	param
	(
        $fRestart = $false
	)
	begin
	{
		$fErrorActionPreference = 'Stop'
	}
	process
	{		
        try
		{
            If ($fRestart)
            {
                LogIt -message ("Installing drivers with restart") -component "MODULE_Drivers" -type "Verbose"
                pnputil /add-driver "$Path\*.inf" /subdirs /install /reboot | Out-File -FilePath (Join-Path -Path $Path -ChildPath "pnputil.log") -Append
            }
            Else
            {
                LogIt -message ("Installing drivers without restart") -component "MODULE_Drivers" -type "Verbose"
                pnputil /add-driver "$Path\*.inf" /subdirs /install | Out-File -FilePath (Join-Path -Path $Path -ChildPath "pnputil.log") -Append
            }
        }
        Catch
        {
            Invoke-ErrorHandler -Message "Critical error installing drivers." -Exception $_
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
		[string]$fDriverGUID,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$fSCCMDistributionPoint,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$fCredential,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [bool]$fHTTPS
	)
	begin
	{
		$fErrorActionPreference = 'Stop'
	}
	process
	{
        LogIt -message ("Getting list of drivers from IIS") -component "MODULE_Drivers" -type "Verbose"
        LogIt -message ("Path: "+$Path) -component "MODULE_Drivers" -type "Debug"
        LogIt -message ("DriverGUID: "+$fDriverGUID) -component "MODULE_Drivers" -type "Debug"
        LogIt -message ("SCCMDistributionPoint: "+$fSCCMDistributionPoint) -component "MODULE_Drivers" -type "Debug"

        if ($fCredential)
        {
            LogIt -message ("Credential: "+($fCredential.UserName.ToString())) -component "MODULE_Drivers" -type "Debug"
        }

		try
		{
            if (-not (Test-Path -Path $Path))
            {
                LogIt -message ("Driver download path does not exist.  Exiting...") -component "MODULE_Drivers" -type "Error"
                Exit 3
            }

            #$fDriverGUID = "1665CB2C-8B4F-4404-B4E5-94B527978D05"

            $fdriverpath = Join-Path -Path $Path -ChildPath $fDriverGUID

            if (Test-Path -Path $fdriverpath)
            {
                LogIt -message ("Driver folder exists, nuking folder from orbit.") -component "MODULE_Drivers" -type "Warning"
                Remove-Item $fdriverpath -Force -Recurse
            }

            New-Item -ItemType directory -Path $fdriverpath

            LogIt -message ("Fetching: http://"+$fSCCMDistributionPoint+"/SMS_DP_SMSPKG$/"+$fDriverGUID) -component "MODULE_Drivers" -type "Debug"
            If ($fCredential)
            {
                LogIt -message ("Invoking web request with credentials") -component "MODULE_Drivers" -type "Verbose"

                If($fHTTPS)
				{
                    LogIt -message ("Invoke-WebRequest https://"+$fSCCMDistributionPoint+"/NOCERT_SMS_DP_SMSPKG$/"+$fDriverGUID+" -UseBasicParsing -Credential {"+$fCredential.UserName+"} -TimeoutSec 180 -ErrorAction:Stop") -component "MODULE_Drivers" -type "Verbose"
                    $frequest = Invoke-WebRequest https://$fSCCMDistributionPoint/NOCERT_SMS_DP_SMSPKG`$/$fDriverGUID -UseBasicParsing -Credential $fCredential -TimeoutSec 180 -ErrorAction:Stop
                }
				Else
				{
                    LogIt -message ("Invoke-WebRequest http://"+$fSCCMDistributionPoint+"/NOCERT_SMS_DP_SMSPKG$/"+$fDriverGUID+" -UseBasicParsing -Credential {"+$fCredential.UserName+"} -TimeoutSec 180 -ErrorAction:Stop") -component "MODULE_Drivers" -type "Verbose"
                    $frequest = Invoke-WebRequest http://$fSCCMDistributionPoint/SMS_DP_SMSPKG`$/$fDriverGUID -UseBasicParsing -Credential $fCredential -TimeoutSec 180 -ErrorAction:Stop
                }
            }
            Else
            {
                LogIt -message ("Invoking web request without credentials") -component "MODULE_Drivers" -type "Verbose"

                If($fHTTPS)
				{
                    LogIt -message ("Invoke-WebRequest https://"+$fSCCMDistributionPoint+"/NOCERT_SMS_DP_SMSPKG$/"+$fDriverGUID+" -UseBasicParsing -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop") -component "MODULE_Drivers" -type "Verbose"
                    $frequest = Invoke-WebRequest https://$fSCCMDistributionPoint/NOCERT_SMS_DP_SMSPKG`$/$fDriverGUID -UseBasicParsing -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop
                }
				Else
				{
                    LogIt -message ("Invoke-WebRequest http://"+$fSCCMDistributionPoint+"/NOCERT_SMS_DP_SMSPKG$/"+$fDriverGUID+" -UseBasicParsing -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop") -component "MODULE_Drivers" -type "Verbose"
                    $frequest = Invoke-WebRequest http://$fSCCMDistributionPoint/SMS_DP_SMSPKG`$/$fDriverGUID -UseBasicParsing -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop
                }
            }

            $flinks = $frequest.Links.outerHTML

            foreach ($flink in $flinks)
            {
                Write-Host "Downloading: $fFileName"

                $fURL = $flink.Split("""")[1]

                #We can get different casing on this, use RegEx to handle that scenario
                If($fHTTPS)
				{
                    $fURL = $fURL.replace("http://","https://")
                	$fFileName = $fURL -ireplace [regex]::Escape("https://$fSCCMDistributionPoint/NOCERT_SMS_DP_SMSPKG$/$fDriverGUID/"), ""
                }
				Else
				{
                	$fFileName = $fURL -ireplace [regex]::Escape("http://$fSCCMDistributionPoint/SMS_DP_SMSPKG$/$fDriverGUID/"), ""
				}

				$foutfilepath = Join-Path -Path $fdriverpath -ChildPath $fFileName

                try 
                {
                    LogIt -message ("Fetching: "+$fURL) -component "MODULE_Drivers" -type "Debug"
                    If ($fCredential)
                    {
                        LogIt -message ("Invoking web request with credentials") -component "MODULE_Drivers" -type "Debug"
                        LogIt -message ("Invoke-WebRequest -Uri "+$fURL+" -outfile "+$foutfilepath+" -Credential {"+$fCredential.UserName+"} -TimeoutSec 180 -ErrorAction:Stop") -component "MODULE_Drivers" -type "Verbose"
                        $frequest = Invoke-WebRequest -Uri $fURL -outfile $foutfilepath -UseBasicParsing -Credential $fCredential -TimeoutSec 180 -ErrorAction:Stop
                    }
                    Else
                    {
                        LogIt -message ("Invoking web request without credentials") -component "MODULE_Drivers" -type "Debug"
                        LogIt -message ("Invoke-WebRequest -Uri "+$fURL+" -outfile "+$foutfilepath+" -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop") -component "MODULE_Drivers" -type "Verbose"
                        $frequest = Invoke-WebRequest -Uri $fURL -outfile $foutfilepath -UseBasicParsing -UseDefaultCredentials -TimeoutSec 180 -ErrorAction:Stop
                    }
                }
                catch
                {
                    LogIt -message ("Failed to download drivers") -component "MODULE_Drivers" -type "Error"
                    LogIt -message ($_.Exception) -component "MODULE_Drivers" -type "Error"
                    LogIt -message ($_.ErrorDetails.ToSTring()) -component "MODULE_Drivers" -type "Debug"
                }
            }
        }
        Catch
        {
            Invoke-ErrorHandler -Message "Critical error downloading drivers." -Exception $_
        }
    }
}



function Query-DriverListAgainstOnlineOS
{
	<#
	    .SYNOPSIS 
	      Checks drivers against online OS to verify we are only grabbing and updating drivers that have a newer version
	    .DESCRIPTION
        .PARAMETER
          DriverList

	    .EXAMPLE
		    Query-IfAdministrator
	#>

    param (
        $fDriverList
	)

    try
    {
        $fOnlineDrivers = Get-WindowsDriver -Online -All
        $fDriverListFinal = @()

        # Remove drivers that don't need to be updated
        ForEach ($fDriver in $fDriverList)
        {
            # We have to do this in two steps because the date should ALWAYS win even if the version is newer.
            If (($fOnlineDrivers | Where-Object {$_.ClassName -eq $fDriverList[0].DriverClass -and $_.ProviderName -eq $fDriverList[0].DriverProvider -and $_.Driver -eq $fDriverList[0].DriverINFFile -and $_.Date -lt $fDriverList[0].DriverDate}).Count -gt 0)
            {

                LogIt -message ("Found a newer driver, add it to the list.") -component "Main()" -type "Debug"
                $fDriverListFinal += $fDriver
                Continue
            }
            ElseIf (($fOnlineDrivers | Where-Object {$_.ClassName -eq $fDriverList[0].DriverClass -and $_.ProviderName -eq $fDriverList[0].DriverProvider -and $_.Driver -eq $fDriverList[0].DriverINFFile -and [Version]$_.Version -lt [Version]$fDriverList[0].DriverVersion -and $_.Date -lt $fDriverList[0].DriverDate}).Count -gt 0)
            {
                LogIt -message ("Found a newer driver, add it to the list.") -component "Main()" -type "Debug"
                $fDriverListFinal += $fDriver
                Continue
            }
            Else
            {
                LogIt -message ("No newer driver found, skip!") -component "Main()" -type "Debug"
                Continue
            }
        }

        Return $fDriverListFinal
    }
    catch
    {
        $fMessage = "Critical error checking driver list against online oeprating system."
        Invoke-ErrorHandler -Message $fMessage -Exception $_
        Return $fMessage
    }
}



function Query-XMLDevices
{
	<#
	    .SYNOPSIS 
	      Forms the XML for driver structure
	    .DESCRIPTION
	    .EXAMPLE
		    Example function calls
	#>

    param (
        $fDevices,
        [switch]$fPrettyPrint
	)

    Try
    {


        ForEach ($_ in $fDevices){
    
            # Find out all our use cases where we want to skip this device
            If (-not $_)
            {
                Continue
            }

            $fXmlDevices_Xml += "<Device>"

            If ($fPrettyPrint)
            {
                $fXmlDevices_Xml += "<!-- "+$_.Manufacturer+" | "+$_.FriendlyName+" -->"
            }

            ForEach ($__ in $_.HardwareID)
            {
                If ($__.ToString() -like "*\*")
                {
                    $fXmlDevices_Xml += "<HwId>"+$__.ToString()+"</HwId>"
                }
                Else
                {
                    Continue
                }

                If ($__.ToString() -like "*{*")
                {
                    # Fixes an issue where items with curly braces seem to not match unless we strip the first part.
                    # Edge case but vOv
                    $fXmlDevices_Xml += "<HwId>"+$__.Split("\")[1].ToString()+"</HwId>"
                }
        
            }

            $fXmlDevices_Xml += "</Device>"

        }

        $fXmlDevices_Xml = $fXmlDevices_Xml.Replace("&","&amp;")
        Return $fXmlDevices_Xml
    }
    Catch
    {
        LogIt -message ("Cannot get local hardware devices.") -component "MODULE_Functions" -type "Error"
        LogIt -message ("Continuing with fake hardware list.") -component "MODULE_Functions" -type "Warning"
        $fXmlDevices_Xml = "<Device><!-- Microsoft | Microsoft XPS Document Writer (redirected 2) --><HwId>PRINTENUM\LocalPrintQueue</HwId></Device><Device><!-- Microsoft | Microsoft Print to PDF (redirected 2) --><HwId>PRINTENUM\LocalPrintQueue</HwId></Device><Device><!-- Microsoft | Microsoft Print to PDF --><HwId>PRINTENUM\{084f01fa-e634-4d77-83ee-074817c03581}</HwId><HwId>{084f01fa-e634-4d77-83ee-074817c03581}</HwId><HwId>PRINTENUM\LocalPrintQueue</HwId></Device><Device><!-- Microsoft | Microsoft XPS Document Writer --><HwId>PRINTENUM\{0f4130dd-19c7-7ab6-99a1-980f03b2ee4e}</HwId><HwId>{0f4130dd-19c7-7ab6-99a1-980f03b2ee4e}</HwId><HwId>PRINTENUM\LocalPrintQueue</HwId></Device>"

        Return $fXmlDevices_Xml
    }
}



function Query-XMLCategory
{
	<#
	    .SYNOPSIS 
	      Queries Category Information from the DB
	    .DESCRIPTION
	    .EXAMPLE
		    Example function calls
	#>

    param (
        [System.Array]$fCategories
	)


    try
    {
        If (-not $fCategories)
        {
            Return ""
        }

        $fCategoryInstance_UniqueIDs = @()

        If ($fCategories)
        {
            LogIt -message ("Querying driver category information.") -component "MODULE_Functions" -type "Verbose"


            $fXMLCategory_xml += "<Categories>"

            # WMI query: SELECT * FROM SMS_CategoryInstance where CategoryTypeName = 'DriverCategories'
            # https://cm1/AdminService/wmi/CategoryInstance?$ffilter=CategoryTypeName
            ForEach ($fCategory in $fCategories)
            {
                If ($fCategoryWildCard)
                {
                    $fSqlQuery = "SELECT CategoryInstance_UniqueID FROM v_CategoryInfo WHERE CategoryTypeName = 'DriverCategories' AND IsDeleted = '0' AND CategoryInstanceName LIKE '%$fCategory%'"
                }
                Else
                {
                    $fSqlQuery = "SELECT CategoryInstance_UniqueID FROM v_CategoryInfo WHERE CategoryTypeName = 'DriverCategories' AND IsDeleted = '0' AND CategoryInstanceName = '$fCategory'"
                }

                if ($fCredential)
                {
                    $freturn = Invoke-SqlCommand -ServerName $fSCCMServer -Database $fSCCMServerDB -Name $fSqlQuery -Credential $fCredential
                }
                else
                {
                    $freturn = Invoke-SqlCommand -ServerName $fSCCMServer -Database $fSCCMServerDB -Name $fSqlQuery
                }

                $fXMLCategory_xml += "<Category>"+$freturn[1].Rows[0][0].ToString()+"</Category>"
            }

            $fXMLCategory_xml += "</Categories>"
        }

        $fXMLCategory_xml = $fXMLCategory_xml.Replace("&","&amp;")
        Return $fXMLCategory_xml
    }
    Catch
    {
        Invoke-ErrorHandler -Message "Critical error getting category information." -Exception $_
        Return ""
    }
}