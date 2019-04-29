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
    $rootdir
    )

$results = @{}
Get-ChildItem -Recurse -Include backup.xml $rootdir | ForEach-Object{
    $guid = $_.Directory.Name
    $x = [xml](Get-Content $_)
    $dn = $x.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
    # $dn + "`t" + $guid
    $results.Add($dn, $guid)
    Import-GPO -BackupId $guid -Path (Get-Item (get-item $_.PSParentPath).PSParentPath).FullName -TargetName $dn -CreateIfNeeded
}
$results | Format-Table Name, Value -AutoSize
