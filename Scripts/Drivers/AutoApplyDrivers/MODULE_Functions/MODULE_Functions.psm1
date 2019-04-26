Write-Debug "Loading: MODULE_Functions"

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
        $tsenv._SMSTSMP = $tsenv._SMSTSMP.replace("http://","")
        $tsenv._SMSTSMP = $tsenv._SMSTSMP.replace("https://","")
        $tsenv.SMSTSMP = $tsenv.TSEnvironment.Value("SMSTSMP")
        $tsenv.SMSTSMP = $tsenv.SMSTSMP.replace("http://","")
        $tsenv.SMSTSMP = $tsenv.SMSTSMP.replace("https://","")


        $tsenv._SMSTSAssignedSiteCode = $tsenv.TSEnvironment.Value("_SMSTSAssignedSiteCode")

        # This doesn't work right.  We can get the variables but passing it in breaks when trying to connect to SQL :(
        # Leaving here in case we ever come back to fix it.
        # $TSUsernameVar = $tsvars | Where-Object {$_ -like "_SMSTSReserved1*"}
        # $TSPasswordVar = $tsvars | Where-Object {$_ -like "_SMSTSReserved2*"}

        # $tsenv.TSVar_Username = $tsenv.Value($TSUsernameVar)
        # $tsenv.TSVar_Password = $tsenv.Value($TSPasswordVar) | ConvertTo-SecureString -asPlainText -Force

        $HttpDpVar = $tsvars | Where-Object {$_ -like "_SMSTSHTTP$tsenv._SMSTSAssignedSiteCode*"}
        $HttpsDpVar = $tsvars | Where-Object {$_ -like "_SMSTSHTTPS$tsenv._SMSTSAssignedSiteCode*"}

        ForEach ($_ in $HttpDpVar)
        {
            $tsenv._SMSTSHTTP = $tsenv.Value($HttpDpVar)
            $tsenv._SMSTSHTTP = ($tsenv._SMSTSHTTP.Split("/"))[2]
            # Only need first one so break out
            Break
        }

        ForEach ($_ in $HttpsDpVar)
        {
            $tsenv._SMSTSHTTPS = $tsenv.Value($HttpsDpVar)
            $tsenv._SMSTSHTTPS = ($tsenv._SMSTSHTTPS.Split("/"))[2]
            # Only need first one so break out
            Break
        }

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
        If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] �Administrator�))
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
        Invoke-ErrorHandler -Message "Critical error checking for administrative permissions." -Exception $_
    }

}

function Invoke-ErrorHandler
{
	<#
	    .SYNOPSIS
	      Handles an error outputting standard information and optionally exiting.
	    .DESCRIPTION
	    .EXAMPLE
		    Invoke-ErrorHandler -Message "This is an error" -LogFile "C:\Logfile.log" -ExitCode "666"
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

        If ($Exception)
        {
            LogIt -message (" ") -component "MODULE_ErrorHandler" -type "Error"
            LogIt -message ("Error information:") -component "MODULE_ErrorHandler" -type "Error"

            If ($Exception.Exception.Message)
            {
                LogIt -message ($Exception.Exception.Message) -component "MODULE_ErrorHandler" -type "Error"
            }

            if ($Exception.InvocationInfo.Line)
            {
                LogIt -message ("Invocation Info: "+$incomingError.InvocationInfo.Line) -component "MODULE_ErrorHandler" -type "Debug"
            }

            if ($Exception.TargetObject)
            {
                LogIt -message ("Target Object: "+$incomingError.TargetObject) -component "MODULE_ErrorHandler" -type "Debug"
            }

            If ($Exception.ErrorDetails)
            {
                LogIt -message ($Exception.ErrorDetails.ToSTring()) -component "MODULE_ErrorHandler" -type "Debug"
            }

            If ($Exception.Exception)
            {
                LogIt -message ($Exception.Exception) -component "MODULE_ErrorHandler" -type "Verbose"
            }
        }


        If ($ExitCode)
        {
            LogIt -message ("Exiting with code: "+$ExitCode) -component " " -type "Warning"
            Exit $ExitCode
        }
    }
    Catch
    {
        Write-Host -ForegroundColor Red "Error attempting to handle a passed in error."

        If ($Message)
        {
            Write-Host -ForegroundColor Red $Message
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
