Write-Host "Loading: MODULE_Functions"

function Get-TSEnvironment
{
	<#
	    .SYNOPSIS 
	      Connects to a task sequence environment and fetches variables
	    .DESCRIPTION
	    .EXAMPLE
		    Example function calls
		    Get-TSEnvironment
	#>

    param (
	)

    $tsenv = @{}

    Try
    {
        LogIt -message ("Getting Task Sequence environment and variables.") -component "MODULE_Functions" -type "DEBUG"

        $tsenv.TSEnvironment = New-Object -COMObject Microsoft.SMS.TSEnvironment

        $tsenv.TSVariableList = $tsenv.TSEnvironment.GetVariables()

        # Get TS Variable Values
        $tsenv._SMSTSMP = $tsenv.TSEnvironment.Value("_SMSTSMP")
        $tsenv.TSVar_Path = $tsenv.TSEnvironment.Value("TSVar_Path")
        $tsenv.TSVar_SCCMServerDB = $tsenv.TSEnvironment.Value("TSVar_SCCMServerDB")
        $tsenv.TSVar_InstallDrivers = $tsenv.TSEnvironment.Value("TSVar_InstallDrivers")
        $tsenv.TSVar_Categories = $tsenv.TSEnvironment.Value("TSVar_Categories")
        $tsenv.TSVar_DownloadDrivers = $tsenv.TSEnvironment.Value("TSVar_DownloadDrivers")
        $tsenv.TSVar_FindAllDrivers = $tsenv.TSEnvironment.Value("TSVar_FindAllDrivers")
        $tsenv.TSVar_HardwareMustBePresent = $tsenv.TSEnvironment.Value("TSVar_HardwareMustBePresent")
        $tsenv.TSVar_UpdateOnlyDatedDrivers = $tsenv.TSEnvironment.Value("TSVar_UpdateOnlyDatedDrivers")
        # $tsenv.XXXX = $tsenv.TSEnvironment.Value("XXXXX")

        # _SMSTSCHQ00005 = http://cm1.corp.contoso.com/sms_dp_smspkg$/chq00005 
        # Maybe use this for the DP?

        $TSUsernameVar = $tsvars | Where-Object {$_ -like "_SMSTSReserved1*"}
        $TSPasswordVar = $tsvars | Where-Object {$_ -like "_SMSTSReserved2*"}

        $tsenv.TSVar_Username = $tsenv.Value($TSUsernameVar)
        $tsenv.TSVar_Password = $tsenv.Value($TSPasswordVar) | ConvertTo-SecureString -asPlainText -Force

        Return $tsenv
    }
    Catch
    {
        Return $false
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
        LogIt -message ("Formatting XML output.") -component "MODULE_Functions" -type "DEBUG"
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


function Validate-CriticalParameters
{
	<#
	    .SYNOPSIS 
	      Validates paramaters that are critical and cannot be missing.
	    .DESCRIPTION
	    .EXAMPLE
		    Example function calls
		    Get-TSEnvironment
	#>

    param (
        [System.Array]$Parameters
	)

    Try
    {
        LogIt -message ("Validating critical parameters.") -component "MODULE_Functions" -type "DEBUG"

        $Count = 0

        ForEach ($_ in $Parameters)
        {
            If (-not $_)
            {
                LogIt -message ("Found missing parameter") -component "MODULE_Functions" -type "ERROR"
                $Count++
            }
        }

        Return $Count
    }
    Catch
    {
        LogIt -message ("Critical error validating critical parameters.") -component "MODULE_Functions" -type "ERROR"
        Return 666
    }
}


function Query-IfAdministrator
{
	<#
	    .SYNOPSIS 
	      Verifies that the current execution context has administrative rights
	    .DESCRIPTION
	    .EXAMPLE
		    Query-IfAdministrator
	#>

    param (
	)

    try
    {
        If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] “Administrator”))
        {
            Return $True
        }
        Else
        {
            Return $False
        }
    }
    catch
    {
        Handle-Error -Message "Critical error checking for administrative permissions." -Exception $_
    }

}

function Handle-Error
{
	<#
	    .SYNOPSIS 
	      Handles an error outputting standard information and optionally exiting.
	    .DESCRIPTION
	    .EXAMPLE
		    Handle-Error -Message "This is an error" -LogFile "C:\Logfile.log" -ExitCode "666"
	#>

    param (
        [string]$Message,
        $Exception,
        [int]$ExitCode
	)

    Try
    {
        If ($Message)
        {
            LogIt -message ($Message) -component "MODULE_ErrorHandler" -type "Error"
        }

        If ($_.Exception)
        {
            LogIt -message ($_.Exception) -component "MODULE_ErrorHandler" -type "Error"
        }

        If ($_.ErrorDetails)
        {
            LogIt -message ($_.ErrorDetails.ToSTring()) -component "MODULE_ErrorHandler" -type "Debug"
        }

        If ($ExitCode)
        {
            LogIt -message (" ") -component " " -type "Info"
            Exit $ExitCode
        }
    }
    Catch
    {
        If ($Message)
        {
            Write-Host -ForegroundColor Red "Critical error checking for administrative permissions."
        }

        If ($_.Exception)
        {
            Write-Host -ForegroundColor Red $_.Exception
        }

        If ($_.ErrorDetails)
        {
            Write-Host -ForegroundColor Red $_.ErrorDetails.ToSTring()
        }

        If ($ExitCode)
        {
            Exit $ExitCode
        }
    }
}