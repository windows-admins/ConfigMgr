# Map GUIDs to GPO display names
<#
.SYNOPSIS
.DESCRIPTION
.PARAMETER rootdir
.EXAMPLE
#>

param(
    [parameter(Mandatory=$true)]
    [String]
    $rootdir,
    [parameter(Mandatory=$true)]
    [String]
    $version
    )

$results = @{}
$STIGs = Get-ChildItem -Filter DoD* $rootdir

ForEach ($STIG in $STIGs)
{
    $pathGPO = $rootdir + "\" + $STIG.Name + "\GPO"
    $pathGPOs = $rootdir + "\" +  $STIG.Name + "\GPOs"

    Write-Host $pathGPO
    if (Test-Path -Path $pathGPO)
    {
        $GPOBackup = Get-ChildItem -Filter {*} $pathGPO
        $name = "STIG " + $version + " " + $STIG.Name
        Write-Host "Creating STIG: " $name
        Import-GPO -BackupId $GPOBackup.Name -Path $pathGPO -TargetName $name -CreateIfNeeded
    }
    elseif (Test-Path -Path $pathGPOs)
    {
        $GPOBackups = Get-ChildItem -Filter {*} $pathGPOs
        $count = 1

        ForEach ($GPOBackup in $GPOBackups)
        {
            $name = "STIG " + $version + " " + $STIG.Name + " [" + $count + "]"
            Write-Host $name
            Import-GPO -BackupId $GPOBackup.Name -Path $pathGPOs -TargetName $name -CreateIfNeeded
            $count++
        }
    }
    else
    {
        Write-Host "How did you get here for STIG: " $STIG.Name
    }

}
