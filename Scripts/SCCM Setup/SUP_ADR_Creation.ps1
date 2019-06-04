#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '6/3/2019 12:42:50 PM'.

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



# New-CMSoftwareUpdateAutoDeploymentRule -CollectionId "DOGFOOD01" -DeploymentPackage $CMSoftwareUpdateDeploymentPackage -Name "DeploymentRule07" -ArticleId "117"

# $CMSoftwareUpdateDeploymentPackage = New-CMSoftwareUpdateDeploymentPackage -Name "Windows 10" -Path "\\cm1.corp.contoso.com\Source\_Updates\Windows 10"

# $CMCollection = Get-CMCollection -Id DOGFOOD1 -CollectionType Device

# New-CMSoftwareUpdateAutoDeploymentRule -Collection $CMCollection -Product 'Windows 10', 'Windows 10, version 1903 and later' -Superseded $False -DeploymentPackage $CMSoftwareUpdateDeploymentPackage -Name "Windows 10" -AddToExistingSoftwareUpdateGroup $True -AllowRestart $False -AllowSoftwareInstallationOutsideMaintenanceWindow $False -AllowUseMeteredNetwork $False -EnabledAfterCreate $True -Enable $True -SendWakeupPacket $True -DeployWithoutLicense $False -RunType RunTheRuleAfterAnySoftwareUpdatePointSynchronization -SuppressRestartServer $True -SuppressRestartWorkstation $False -WriteFilterHandling $True -NoInstallOnRemote $True -NoInstallOnUnprotected $True -AvailableImmediately $True -DeadlineImmediately $True

$ContentSourcePath = "\\cm1.corp.contoso.com\Source\_Updates\"

$collections = (”DOGFOOD1”,”DOGFOOD2”,”DOGFOOD3”,”DOGFOOD4”,”DOGFOOD5”,”DOGFOOD6”,”DOGFOOD7”,”DOGFOOD8”)

$ADRRules = (`
@{
    ADRName = "Windows 10"; 
    Products = 'Windows 10', 'Windows 10, version 1903 and later';
    UpdateClassifications = "Critical Updates", "Definition Updates", "Feature Packs", "Security Updates","Service Packs", "Tools", "Update Rollups","Updates";
    Title = "-en-gb"
},`
@{
    ADRName = "Office 365"; 
    Products = 'Office 365 Client';
    UpdateClassifications = "Critical Updates", "Definition Updates", "Feature Packs", "Security Updates","Service Packs", "Tools", "Update Rollups","Updates";
    Title = ""
}`
)

$schedule = (`
@{
    Available = 0;
    Required = 3
},
@{
    Available = 1;
    Required = 5
},
@{
    Available = 2;
    Required = 7
},
@{
    Available = 8;
    Required = 22
},
@{
    Available = 10;
    Required = 24
},
@{
    Available = 12;
    Required = 26
},
@{
    Available = 14;
    Required = 28
},
@{
    Available = 16;
    Required = 30
}
)

ForEach ($ADRRule in $ADRRules)
{
    $DeploymentPackagePath = New-Item -Path "FileSystem::$ContentSourcePath" -Name $ADRRule.ADRName -ItemType "directory"
    $CMSoftwareUpdateDeploymentPackage = New-CMSoftwareUpdateDeploymentPackage -Name $ADRRule.ADRName -Path $DeploymentPackagePath.FullName -Priority High

    $CMSoftwareUpdateAutoDeploymentRule = New-CMSoftwareUpdateAutoDeploymentRule `
    -Collection (Get-CMCollection -Id $collections[0] -CollectionType Device) `
    -DeploymentPackage $CMSoftwareUpdateDeploymentPackage `
    -Name $ADRRule.ADRName `
    -AddToExistingSoftwareUpdateGroup $True `
    -AlertTime 4 `
    -AlertTimeUnit Weeks `
    -AllowRestart $True `
    -AllowSoftwareInstallationOutsideMaintenanceWindow $False `
    -AllowUseMeteredNetwork $True `
    -AvailableTime $schedule[0].Available `
    -AvailableTimeUnit Days `
    -DeadlineTime $schedule[0].Required `
    -DeadlineTimeUnit Days `
    -DeployWithoutLicense $True `
    -DisableOperationManager $True `
    -DownloadFromInternet $True `
    -DownloadFromMicrosoftUpdate $True `
    -EnabledAfterCreate $True `
    -GenerateOperationManagerAlert $True `
    -GenerateSuccessAlert $True `
    -Language "English" `
    -LanguageSelection "English" `
    -NoInstallOnRemote $False `
    -NoInstallOnUnprotected $True `
    -Product $ADRRule.Products `
    -RunType RunTheRuleAfterAnySoftwareUpdatePointSynchronization `
    -SendWakeUpPacket $True `
    -SuccessPercent 99 `
    -Superseded $False `
    -SuppressRestartServer $False `
    -SuppressRestartWorkstation $False `
    -Title $ADRRule.Title `
    -UpdateClassification $ADRRule.UpdateClassifications `
    -UseBranchCache $False `
    -UserNotification DisplayAll `
    -UseUtc $True `
    -VerboseLevel AllMessages `
    -WriteFilterHandling $True 

    $Count=0
    ForEach ($_ in $schedule)
    {
        If ($Count -eq 0)
        {
            $Count++
            Continue
        }

        New-CMAutoDeploymentRuleDeployment `
        -InputObject $CMSoftwareUpdateAutoDeploymentRule `
        -Collection (Get-CMCollection -Id $collections[$Count] -CollectionType Device) `
        -AvailableTime $_.Available `
        -AvailableTimeUnit Days `
        -DeadlineTime $_.Required `
        -DeadlineTimeUnit Days `
        -EnableDeployment $True `
        -UseUtc $True `
        -SendWakeupPacket $True `
        -UserNotification DisplayAll `
        -AllowSoftwareInstallationOutsideMaintenanceWindow $False `
        -WriteFilterHandling $True

        $Count++
    }

}