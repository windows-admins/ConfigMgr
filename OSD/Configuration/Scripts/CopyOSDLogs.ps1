<#
    Name: CopyOSDLogs.ps1
    Version: 1.0
    Author: Johan Schrewelius, Onevinn AB
    Date: 2016-11-12
    Command: powershell.exe -executionpolicy bypass -file CopyOSDLogs.ps1
    Usage: Run in SCCM Task Sequence Error handling Section to zip and copy SMSTSLog folder to Share.
    Config: 
        $ComputerNameVariable = "OSDComputerName"
#>


# Config Start

$ComputerNameVariable = "OSDComputerName"

# Config End

function Authenticate {
    param(
        [string]$UNCPath = $(Throw "An UNCPath must be specified"),
        [string]$User,
        [string]$PW
    )

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "net.exe"
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "USE $($UNCPath) /USER:$($User) $($PW)"
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
}

function ZipFiles {
    param(
        [string]$ZipFileName,
        [string]$SourceDir
    )

   Add-Type -Assembly System.IO.Compression.FileSystem
   $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDir, $ZipFileName, $compressionLevel, $false)
}

try {
    $dt = get-date -Format "yyyy-MM-dd-HH-mm-ss"
    $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
    $LogPath = $tsenv.Value("SLShare")
    $CmpName = $tsenv.Value("$ComputerNameVariable")
    $source =  $tsenv.Value("_SMSTSLogPath")
    $NaaUser = $tsenv.Value("_SMSTSReserved1-000")
    $NaaPW = $tsenv.Value("_SMSTSReserved2-000")

    New-Item "$source\tmp" -ItemType Directory -Force
    Copy-Item "$source\*" "$source\tmp" -Force -Exclude "tmp"
    $source = "$source\tmp"

    try { # Catch Error if already authenticated
        Authenticate -UNCPath $LogPath -User $NaaUser -PW $NaaPW
    }
    catch {}

    $filename =  Join-Path -Path "$LogPath" -ChildPath "$($CmpName )-$($dt).zip"
    ZipFiles -ZipFileName $filename -SourceDir $source

    Remove-Item -Path "$source" -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Output "$_.Exception.Message"
    exit 1
}