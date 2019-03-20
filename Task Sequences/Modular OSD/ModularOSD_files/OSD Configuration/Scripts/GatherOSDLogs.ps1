$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$SMSTSLogPath =  $tsenv.Value("_SMSTSLogPath")

$DesiredLogs = @(
"$env:SystemRoot\INF\setupapi.setup.log",
"$env:SystemRoot\Logs\CBS",
"$env:SystemRoot\Logs\DISM",
"$env:SystemRoot\Panther"
)

ForEach ($Log in $DesiredLogs)
{
    if (Test-Path $Log)
    {
        Write-host "Copying: $Log"
        Copy-Item -Recurse -Path $Log -Destination $SMSTSLogPath -Force
    }
    Else
    {
        Write-host "$Log does not exist."
    }
}
