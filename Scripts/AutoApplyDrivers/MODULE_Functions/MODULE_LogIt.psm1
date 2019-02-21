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
	    [Parameter(Mandatory=$true)]
		[ValidateSet("Info","Warning","Error","Verbose", "Debug")] 
	    [string]$type,
		[string]$LogFile = $PSScriptRoot + "\LogIt.log"
	)

#    switch ($type)
#    {
#        1 { $type = "Info" }
#        2 { $type = "Warning" }
#        3 { $type = "Error" }
#        4 { $type = "Verbose" }
#    }

    If (-not (Test-Path -Path $LogFile))
    {
        write-host "Creating $LogFile in UTF-8"
        $filename = "$LogFile"
        $text = ""
        [IO.File]::WriteAllLines($filename, $text, [System.Text.Encoding]::UTF8)
    }


    if (($type -eq "Verbose") -and ($Global:Verbose))
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message
    }
    elseif ($type -eq "Error")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message -foreground "red"
    }
    elseif ($type -eq "Warning")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message -foreground "yellow"
    }
    elseif ($type -eq "Info")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message -foreground "white"
    }
    elseif ($type -eq "Debug")
    {
        If ($Global:Debug)
        {
            $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
            $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
            Write-Host $message -foreground "white"
        }
    }
    else
    {
        Write-Host $message -foreground "white"
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