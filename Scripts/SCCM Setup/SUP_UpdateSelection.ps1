#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '5/31/2019 12:39:51 PM'.

# Uncomment the line below if running in an environment where script signing is 
# required.
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Site configuration
$SiteCode = "CHQ" # Site code 
$ProviderMachineName = "CM1.corp.contoso.com" # SMS Provider machine name

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

# Set the Update Classifications
Set-CMSoftwareUpdatePointComponent -AddUpdateClassification 'Critical Updates', 'Definition Updates', 'Feature Packs', 'Security Updates', 'Service Packs', 'Update Rollups', 'Updates', 'Upgrades'

# Office 365
Set-CMSoftwareUpdatePointComponent -AddProduct 'Office 365 Client'

# Windows 10
Set-CMSoftwareUpdatePointComponent -AddProduct 'Windows 10', 'Windows 10 Feature On Demand', 'Windows 10, version 1903 and later'
Set-CMSoftwareUpdatePointComponent -AddProduct 'Windows 10 Language Interface Packs', 'Windows 10 Language Packs'
Set-CMSoftwareUpdatePointComponent -AddProduct 'Windows 10 LTSB'

# Windows Defender
Set-CMSoftwareUpdatePointComponent -AddProduct 'Windows Defender'

# Clean up selected languages
Set-CMSoftwareUpdatePointComponent -RemoveLanguageSummaryDetail 'Arabic', 'Bulgarian', 'Chinese (Simplified, PRC)', 'Chinese (Traditional, Hong Kong S.A.R.)', 'Chinese (Traditional, Taiwan)', 'Croatian', 'Czech', 'Danish', 'Dutch', 'Estorian', 'Finnish', 'French', 'German', 'Greek', 'Hebrew', 'Hindi', 'Hungarian', 'Italian', 'Japanese', 'Korean', 'Latvia', 'Lituanian', 'Norwegian', 'Polish', 'Portugese', 'Portuguese (Brazil)', 'Romanian', 'Russian', 'Serbian', 'Slovak', 'Slovarian', 'Spanish', 'Swedish', 'Thai', 'Turkish', 'Ukranian'
Set-CMSoftwareUpdatePointComponent -RemoveLanguageUpdateFile 'Arabic', 'Bulgarian', 'Chinese (Simplified, PRC)', 'Chinese (Traditional, Hong Kong S.A.R.)', 'Chinese (Traditional, Taiwan)', 'Croatian', 'Czech', 'Danish', 'Dutch', 'Estorian', 'Finnish', 'French', 'German', 'Greek', 'Hebrew', 'Hindi', 'Hungarian', 'Italian', 'Japanese', 'Korean', 'Latvia', 'Lituanian', 'Norwegian', 'Polish', 'Portugese', 'Portuguese (Brazil)', 'Romanian', 'Russian', 'Serbian', 'Slovak', 'Slovarian', 'Spanish', 'Swedish', 'Thai', 'Turkish', 'Ukranian'
Set-CMSoftwareUpdatePointComponent -AddLanguageSummaryDetail 'English'
Set-CMSoftwareUpdatePointComponent -AddLanguageUpdateFile 'English'
