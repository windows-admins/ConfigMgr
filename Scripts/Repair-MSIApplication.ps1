<#
.SYNOPSIS
    Copy an MSI file to its original install location and repair it.
.DESCRIPTION
    This function was written due to an interesting scenario we ran into, where an MSI would not repair
    or uninstall unless the file was in the same exact location it installed from. As we utilize MECM,
    this was an issue because the cache would often get cleared and the file was no longer there. The dev 
    had no interest in fixing their product (even though their other products behaved correctly).

    The script reads the fed MSI application, pulls the GUID, searches the registry for the InstallLocation
    value, then copies the file back to the original location and runs a repair from there.
.INPUTS
    -Source "C:\Some\Folder\App.msi" - Make sure to include the .MSI, not just the directory.
    -Confirm:$false - Acknowledge you are going to nuke an MSI of the same name, if found there
.NOTES
    Name:      Repair-MSIApplication.ps1
    Author:    Vex
    Contributor:    Chris Kibble
                    Nickolaj Andersen (Unknowingly, as I borrowed his script and used it within; credit/link commented below)
    Version: 1.0.0
    Release Date: 2019-11-20
#>

Function Repair-MSIApplication {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    # Registry keys for native and WOW64 applications
    [string[]]$regKeyPaths = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    # Grab the MSI for later
    $sourceDir = Split-Path $source
    $msi = Split-Path $source -Leaf

    # Embedding Nickolaj's MSI script and making it a function: https://www.scconfigmgr.com/2014/08/22/how-to-get-msi-file-information-with-powershell/
    Function Get-MSIFileInformation {
        param(
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [System.IO.FileInfo]$Path,
 
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("ProductCode", "ProductVersion", "ProductName", "Manufacturer", "ProductLanguage", "FullVersion")]
            [string]$Property
        )
        Process {
            try {
                # Read property from MSI database
                $WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
                $MSIDatabase = $WindowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $WindowsInstaller, @($Path.FullName, 0))
                $Query = "SELECT Value FROM Property WHERE Property = '$($Property)'"
                $View = $MSIDatabase.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $MSIDatabase, ($Query))
                $View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
                $Record = $View.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $View, $null)
                $Value = $Record.GetType().InvokeMember("StringData", "GetProperty", $null, $Record, 1)
 
                # Commit database and close view
                $MSIDatabase.GetType().InvokeMember("Commit", "InvokeMethod", $null, $MSIDatabase, $null)
                $View.GetType().InvokeMember("Close", "InvokeMethod", $null, $View, $null)
                $MSIDatabase = $null
                $View = $null
 
                # Return the value
                return $Value
            } 
            catch {
                Write-Warning -Message $_.Exception.Message ; break
            }
        }
        End {
            # Run garbage collection and release ComObject
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WindowsInstaller) | Out-Null
            [System.GC]::Collect()
        }
    }

    # Use Nickolaj's function to grab the GUID and pass it to the next section
    $guid = Get-MSIFileInformation -Path $Source -Property ProductCode
    # Nickolaj's script is writing an array, with the first 3 items being null. Rather than alter his script an add | Out-Null to the appropriate lines, we are just going to select [3]
    $guid = $guid[3]

    #  Search Native and WOW6432Node, and set the $key and $installDir
    ForEach ($regKeyPath in $regKeyPaths) {
        If (Test-Path "$regKeyPath\$guid") {
            $key = "$regKeyPath\$guid"
            $installDir = (Get-ItemProperty -Path $key -Name InstallSource).InstallSource
            $displayName = (Get-ItemProperty -Path $key -Name DisplayName).DisplayName
        }
    }

    $appInstall = Join-Path $installDir $msi

    # Check if the InstallSource directory from the registry exists; if it does not, create it
    If (!(Get-Item $installDir -ErrorAction SilentlyContinue)) {
        New-Item -ItemType Directory -Path $installDir
    }

    # Check if the MSI file already exists in the directory. If it does, remove the file in case its a different file/version of the same name
    If (Test-Path $appInstall) {
        If ($PSCmdlet.ShouldProcess("Delete existing MSI from Target Path?")) {
            Remove-Item $appInstall -Force
        }
        Else {
            Throw "Target MSI exists and overwrite not permitted."
        }
    }

    # Why Robocopy? Because I hate Copy-Item, and quite often have random permission issues with it
    Robocopy.exe $sourceDir $installDir $msi

    $date = (Get-Date -Format "yyyy-MM-dd-HHmmss")
    $logFile = "C:\Windows\Logs\Software\$displayName-Repair-$date.log"
    $msiArguments = @(
        "/FA"
        "`"$appInstall`""
        "/QN"
        "/L*v"
        "`"$logFile`""
    )

    # Start-Process breaks when you have white spaces in the -ArgumentList. Thusly we use escaped double quotes and break the params up with commas.
    # https://github.com/PowerShell/PowerShell/issues/5576
    Start-Process "msiexec.exe" -ArgumentList $msiArguments -Wait

}