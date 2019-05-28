<#
.SYNOPSIS
    Add a ConfigMgr Global Condition for BIOS Version, returning a version number to allow for proper comparisons.
.DESCRIPTION
    Add a global condition to a Configuration Manager site to return the device's BIOS Version as a Version.
    The site to connect to can be explicitly specified, or the default connected to when importing the
    ConfigurationManager module can be used.
.EXAMPLE
    BIOSVersion.ps1
    Add the condition to the the current site if in a CMSite PSProvider, or site connected to by default on loading the
    ConfigurationManager module.
.EXAMPLE
    BIOSVersion.ps1 -SiteCode TST -Server cm.contoso.com
    Add the condition to the Configuration Manager site TST on server cm.contoso.com
#>

[CmdLetBinding(DefaultParameterSetName='automaticSite')]
param(
    # Specify a ConfigMgr site to connect to
    [Parameter(ParameterSetName='specificSite', Mandatory=$true)][string]$SiteCode,
    # Specify a ConfigMgr server to connect to
    [Parameter(ParameterSetName='specificSite')][string]$Server
)

# Boilerplate to load ConfigMgr module & move to provider
if (Get-Module ConfigurationManager) {
    Get-Module ConfigurationManager | Import-Module
} else {
    Import-Module (Join-Path $env:SMS_ADMIN_UI_PATH '..\ConfigurationManager.psd1')
}

if ($PSCmdlet.ParameterSetName -eq 'specificSite') {
    # Use specific site code, optionally with specific server
    $PSDrive = Get-PSDrive -PSProvider CMSite -Name $SiteCode -ErrorAction SilentlyContinue
    if ($Server) {
        $PSDrive = $PSDrive | Where-Object Root -eq $Server
        if (!$PSDrive) {$PSDrive = New-PSDrive -PSProvider CMSite -Name $SiteCode -Root $Server -ErrorAction Stop}
    }
    if (!$PSDrive) {
        throw "No CMSite providers matching requirements available"
    } else {Set-Location "${PSDrive}:/"}
} else {
    # Automatically choose a site to use
    if ((Get-Location).Provider -eq 'AdminUI.PS.Provider\CMSite') {$PSDrive = Get-Location}
    else {
        $PSDrive = Get-PSDrive -PSProvider CMSite
        if ($PSDrive.count -gt 1) {throw "Unable to choose a CMSite, please specify using -SiteCode."}
        Set-Location "${PSDrive}:/"
    }
}


# The actual condition script
$scriptText = '$bios = Get-CimInstance win32_bios -Property *
$major = $bios.SystemBiosMajorVersion
$minor = $bios.SystemBiosMinorVersion
return "$major.$minor"'


# Add the condition
New-CMGlobalConditionScript -Name "BIOS Version" -DataType Version -ScriptText $scriptText -ScriptLanguage PowerShell
