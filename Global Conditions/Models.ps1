<#
.SYNOPSIS
    Add a ConfigMgr Global Condition for each model in CM
.DESCRIPTION
    Add a global condition to a Configuration Manager site to test if a device's model matches the one specified in the
    Global Condition. The site to connect to can be explicitly specified, or the default connected to when importing the
    ConfigurationManager module can be used.
.EXAMPLE
    Models.ps1
    Add the condition to the the current site if in a CMSite PSProvider, or site connected to by default on loading the
    ConfigurationManager module.
.EXAMPLE
    Models.ps1 -SiteCode TST -Server cm.contoso.com
    Add the condition to the Configuration Manager site TST on server cm.contoso.com.
#>

[CmdLetBinding(DefaultParameterSetName = 'automaticSite')]
param(
    # Specify a ConfigMgr site to connect to
    [Parameter(ParameterSetName = 'specificSite', Mandatory = $true)][string]$SiteCode,
    # Specify a ConfigMgr server to connect to
    [Parameter(ParameterSetName = 'specificSite')][string]$Server
)

# Boilerplate to load ConfigMgr module & move to provider
if (Get-Module ConfigurationManager) {
    Get-Module ConfigurationManager | Import-Module
}
else {
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
    }
    else {Set-Location "${PSDrive}:/"}
}
else {
    # Automatically choose a site to use
    if ((Get-Location).Provider -eq 'AdminUI.PS.Provider\CMSite') {$PSDrive = Get-Location}
    else {
        $PSDrive = Get-PSDrive -PSProvider CMSite
        if ($PSDrive.count -gt 1) {throw "Unable to choose a CMSite, please specify using -SiteCode."}
        Set-Location "${PSDrive}:/"
    }
}

if (!$SiteCode) {$SiteCode = $PSDrive.Name}
if (!$Server) {$Server = $PSDrive.Root}

# Get a list of the models
$models = Get-CimInstance -Namespace "root\sms\site_$SiteCode" -ClassName SMS_G_System_COMPUTER_SYSTEM -ComputerName $Server |
    Select-Object -ExpandProperty Model |
    Sort-Object -Unique

# Add the conditions
# PowerShell script conditions are used as WQL queries can only return the model, not a true/false comparison.
$models | ForEach-Object {
    $scriptText = "([bool](Get-CimInstance -ClassName Win32_ComputerSystem -Filter `"Model = '$_'`" -ErrorAction SilentlyContinue)).toString()"
    New-CMGlobalConditionScript -Name "Model is $_" -DataType Boolean -ScriptText $scriptText -ScriptLanguage PowerShell
}
