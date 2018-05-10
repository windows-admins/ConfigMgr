# REQUIRES Convert-GPOtoCI.ps1
#
# Fetch off WinAdmins Github or:
# https://blogs.technet.microsoft.com/samroberts/2017/06/19/create-configmgr-configuration-items-from-group-policy-object/
#


#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '4/18/2018 7:16:37 PM'.


param(
    [parameter(Mandatory=$true)]
    [String]
    $GPOName
    )

# Uncomment the line below if running in an environment where script signing is 
# required.
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Site configuration
$SiteCode = "CHQ" # Site code 
$ProviderMachineName = "cm1.corp.contoso.com" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams


$GPOs = Get-GPO -All

ForEach ($GPO in $GPOs)
{
    if ($GPO.DisplayName -like '*'+$GPOName+'*')
    {
        Write-Host "Converting: " $GPO.DisplayName
        C:\Temp\Convert-GPOtoCI.ps1 -GpoTarget $GPO.DisplayName -DomainTarget corp.contoso.com -SiteCode CHQ -Remediate -Severity Critical
    }
    else
    {
        Write-Host "Skipping: " $GPO.DisplayName
    }
}
