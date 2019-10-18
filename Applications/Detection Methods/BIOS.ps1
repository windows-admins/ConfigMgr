# Change the target major and minor version to the desired values.
# Confirmed to work against Dell and HP
$TargetBiosMajorVersion = 1
$TargetBiosMinorVersion = 10

$BiosMajorVersion = (Get-WmiObject -Class Win32_Bios -Property SystemBiosMajorVersion).SystemBiosMajorVersion
$BiosMinorVersion = (Get-WmiObject -Class Win32_Bios -Property SystemBiosMinorVersion).SystemBiosMinorVersion

if ($TargetBiosMajorVersion -ge $BiosMajorVersion)
{
    if ($TargetBiosMinorVersion -ge $BiosMinorVersion)
    {
        Write-Host "Installed"
    }
}
else
{
    # Do nothing
}
