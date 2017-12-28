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
dir -Recurse -Include backup.xml $rootdir | %{
    $guid = $_.Directory.Name
    $x = [xml](gc $_)
    $dn = $x.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
    # $dn + "`t" + $guid
    $results.Add($dn, $guid)
    Import-GPO -BackupId $guid -Path $rootdir -TargetName $dn -CreateIfNeeded
}
$results | ft Name, Value -AutoSize
