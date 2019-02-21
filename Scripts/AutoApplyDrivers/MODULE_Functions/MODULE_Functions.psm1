

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
