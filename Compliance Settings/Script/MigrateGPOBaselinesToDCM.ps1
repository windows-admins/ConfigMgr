# REQUIRES Convert-GPOtoCI.ps1
#
# Fetch off WinAdmins Github or:
# https://blogs.technet.microsoft.com/samroberts/2017/06/19/create-configmgr-configuration-items-from-group-policy-object/
#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '4/18/2018 7:16:37 PM'.


param(
    [parameter(Mandatory=$true)]
    [String]
    $GPOName,
    [parameter(Mandatory=$true)]
    [String]
    $TargetDomain,
    [parameter(Mandatory=$true)]
    [ValidateLength(3,3)]
    [String]
    $SCCMSiteCode,
    [parameter(Mandatory=$true)]
    [String]
    $SCCMSiteServerFQDN
    )

# Uncomment the line below if running in an environment where script signing is
# required.
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Customizations
$initParams = @{}

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}

# Connect to the site's drive if it is not already present
if($null -eq (Get-PSDrive -Name $SCCMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SCCMSiteCode -PSProvider CMSite -Root $SCCMSiteServerFQDN @initParams
}

# Set the current location to be the site code.
Set-Location "$($SCCMSiteCode):\" @initParams


$GPOs = Get-GPO -All

ForEach ($GPO in $GPOs)
{
    if ($GPO.DisplayName -like '*'+$GPOName+'*')
    {
        Write-Host "Converting: " $GPO.DisplayName
        & $PSScriptRoot\Convert-GPOtoCI_1.2.6\Convert-GPOtoCI.ps1 -GpoTarget $GPO.DisplayName -DomainTarget $TargetDomain -SiteCode $SCCMSiteCode -Remediate -Severity Critical
    }
    else
    {
        Write-Host "Skipping: " $GPO.DisplayName
    }
}
