Write-Debug "Loading: MODULE_LogIt"

function LogIt
{
	<#
	    .SYNOPSIS 
	      Creates a log file in the CMTrace format
	    .DESCRIPTION
	    .EXAMPLE
		    Example LogIt function calls
		    LogIt -message ("Starting Logging Example Script") -component "Main()" -type Info 
		    LogIt -message ("Log Warning") -component "Main()" -type Warning 
		    LogIt -message ("Log Error") -component "Main()" -type Error
		    LogIt -message ("Log Verbose") -component "Main()" -type Verbose
		    LogIt -message ("Script Status: " + $Global:ScriptStatus) -component "Main()" -type Info 
		    LogIt -message ("Stopping Logging Example Script") -component "Main()" -type Info
			LogIt -message ("Stopping Logging Example Script") -component "Main()" -type Info -LogFile a.log
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    [string]$message,
	    [Parameter(Mandatory=$true)]
	    [string]$component,
		[ValidateSet("INFO","WARNING","ERROR","VERBOSE", "DEBUG")] 
	    [string]$type,
		[string]$LogFile
	)

#    switch ($type)
#    {
#        1 { $type = "Info" }
#        2 { $type = "Warning" }
#        3 { $type = "Error" }
#        4 { $type = "Verbose" }
#        5 { $type = "Debug" }
#    }

    If (-not $LogFile)
    {
        # Write-Host "Getting global log file"
        $LogFile = $Global:Logfile
    }

    If (-not $LogFile)
    {
        # Write-Host "Setting log file to default location."
        $LogFile = $PSScriptRoot + "\LogIt.log"
    }

    try
    {
        If (-not (Test-Path -Path $LogFile))
        {
            write-host "Creating $LogFile in UTF-8"
            $filename = "$LogFile"
            $text = ""
            [IO.File]::WriteAllLines($filename, $text, [System.Text.Encoding]::UTF8)
        }
        Else
        {
            # Write-Host "Writing log to: $LogFile"
        }
    }
    catch
    {
        Write-Host -ForegroundColor Red "Unable to create the log file. No information will be logged."
        Write-Host $component": "$message
        Return
    }

    $type = $type.ToUpper()
    if ($type -eq "VERBOSE")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        If ($VerbosePreference -ne "SilentlyContinue")
        {
            $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        }
        Write-Verbose $message
    }
    elseif ($type -eq "ERROR")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message  -foreground "Red"
    }
    elseif ($type -eq "WARNING")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Warning $message
    }
    elseif ($type -eq "INFO")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message -foreground "White"
    }
    elseif ($type -eq "DEBUG")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        If ($DebugPreference -ne "SilentlyContinue")
        {
            $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        }
        Write-Debug $message
    }
    else
    {
        Write-Host $message -foreground "Gray"
    }
	
#    if (($type -eq 'Warning') -and ($Global:ScriptStatus -ne 'Error'))
#	{
#		$Global:ScriptStatus = $type
#	}
#	
#    if ($type -eq 'Error')
#	{
#		$Global:ScriptStatus = $type
#	}

    If (-not $Global:MaxLogSizeInKB)
    {
        $Global:MaxLogSizeInKB = 10240
    }

    if ((Get-Item $LogFile).Length/1KB -gt $MaxLogSizeInKB)
    {
        $log = $LogFile
        Remove-Item ($log.Replace(".log", ".lo_"))
        Rename-Item $LogFile ($log.Replace(".log", ".lo_")) -Force
    }


} 