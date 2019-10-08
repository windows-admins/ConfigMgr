#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#

# Uncomment the line below if running in an environment where script signing is 
# required.
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# ____________________________________________________________________________________________
#
# CHANGE SETTINGS BELOW THIS LINE
#
# ____________________________________________________________________________________________

# Site configuration
$SiteCode = "CHQ" # Site code 
$ProviderMachineName = "CM1.corp.contoso.com" # SMS Provider machine name

# Set to the FQDN of where update package content source is stored
$ContentSourcePath = "\\cm1.corp.contoso.com\Source\_Updates\"

# Change this if you want to target a different set of collections.  The number of $collections and the number of $schedule must match.
$collections = (”DOGFOOD1”,”DOGFOOD2”,”DOGFOOD3”,”DOGFOOD4”,”DOGFOOD5”,”DOGFOOD6”,”DOGFOOD7”,”DOGFOOD8”)

# Add ADR rules to create multiple ADRs in a single pass.
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

# Edit the schedule to your requirements.
# It is not recommmended to have the schedule be longer than the ADR run cycle.
# The schedule below assumes that the ADR only runs once a month.
# Required is additive to available. This means that available 1, required 2 means that it's required on the third day, not the second.
$schedule = (`
    @{
        Available = 1;
        Required = 2
    },
    @{
        Available = 2;
        Required = 3
    },
    @{
        Available = 3;
        Required = 4
    },
    @{
        Available = 8;
        Required = 10
    },
    @{
        Available = 10;
        Required = 10
    },
    @{
        Available = 12;
        Required = 10
    },
    @{
        Available = 14;
        Required = 10
    },
    @{
        Available = 16;
        Required = 10
    }
)

# ____________________________________________________________________________________________
#
# DO NOT CHANGE ANYTHING BELOW THIS LINE
#
# ____________________________________________________________________________________________

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


ForEach ($ADRRule in $ADRRules)
{
    Write-Host "Creating ADR rule for:" $ADRRule.ADRName

    if (Test-Path -Path (Join-Path -Path FileSystem::$ContentSourcePath -ChildPath $ADRRule.ADRName))
    {
        Write-Host $ADRRule.ADRName.ToString() "content source folder already exists."
        $DeploymentPackagePath = Resolve-path -Path (Join-Path -Path FileSystem::$ContentSourcePath -ChildPath $ADRRule.ADRName)
    }
    else
    {
        $DeploymentPackagePath = New-Item -Path "FileSystem::$ContentSourcePath" -Name $ADRRule.ADRName -ItemType "directory"
    }

    $CMSoftwareUpdateDeploymentPackage = Get-CMSoftwareUpdateDeploymentPackage -Name $ADRRule.ADRName
    if ($CMSoftwareUpdateDeploymentPackage)
    {
        Write-Host $ADRRule.ADRName.ToString() "deployment package already exists."
    }
    else
    {
        $CMSoftwareUpdateDeploymentPackage = New-CMSoftwareUpdateDeploymentPackage -Name $ADRRule.ADRName -Path $DeploymentPackagePath.FullName -Priority High
    }

    if (Get-CMAutoDeploymentRule -Name $ADRRule.ADRName -Fast)
    {
        Write-Host $ADRRule.ADRName.ToString() "ADR Rule already exists."
    }
    else
    {
        $CMSoftwareUpdateAutoDeploymentRule = New-CMSoftwareUpdateAutoDeploymentRule `
        -Collection (Get-CMCollection -Id $collections[0] -CollectionType Device) `
        -DeploymentPackage $CMSoftwareUpdateDeploymentPackage `
        -Name $ADRRule.ADRName `
        -AddToExistingSoftwareUpdateGroup $True `
        -AllowRestart $False `
        -AvailableTime $schedule[0].Available `
        -AvailableTimeUnit Days `
        -DeadlineTime $schedule[0].Required `
        -DeadlineTimeUnit Days `
        -DeployWithoutLicense $True `
        -DownloadFromMicrosoftUpdate $True `
        -AllowUseMeteredNetwork $False `
        -EnabledAfterCreate $True `
        -GenerateOperationManagerAlert $True `
        -Language "English" `
        -LanguageSelection "English" `
        -NoInstallOnRemote $False `
        -NoInstallOnUnprotected $True `
        -Product $ADRRule.Products `
        -RunType RunTheRuleAfterAnySoftwareUpdatePointSynchronization `
        -Superseded $False `
        -SuppressRestartServer $False `
        -SuppressRestartWorkstation $False `
        -Title $ADRRule.Title `
        -UpdateClassification $ADRRule.UpdateClassifications `
        -UseBranchCache $False `
        -VerboseLevel AllMessages `
        -UseUtc $False `
        -SendWakeupPacket $True `
        -UserNotification DisplayAll `
        -AllowSoftwareInstallationOutsideMaintenanceWindow $False `
        -WriteFilterHandling $True `
        -SoftDeadlineEnabled $True `
        -RequirePostRebootFullScan $True `
        -SuccessPercentage 80 `
        -GenerateSuccessAlert $True `
        -AlertTime 7 `
        -AlertTimeUnit Days

        $Count=0
        ForEach ($_ in $schedule)
        {
            If ($Count -eq 0)
            {
                $Count++
                Continue
            }

            $CMAutoDeploymentRuleDeployment = New-CMAutoDeploymentRuleDeployment `
            -InputObject $CMSoftwareUpdateAutoDeploymentRule `
            -Collection (Get-CMCollection -Id $collections[$Count] -CollectionType Device) `
            -AvailableTime $_.Available `
            -AvailableTimeUnit Days `
            -AllowRestart $False `
            -DeadlineTime $_.Required `
            -DeadlineTimeUnit Days `
            -EnableDeployment $True `
            -UseUtc $False `
            -SendWakeupPacket $True `
            -UserNotification DisplayAll `
            -AllowSoftwareInstallationOutsideMaintenanceWindow $False `
            -WriteFilterHandling $True `
            -SoftDeadlineEnabled $True `
            -RequirePostRebootFullScan $True `
            -SuccessPercentage 80 `
            -GenerateSuccessAlert $True `
            -AlertTime 7 `
            -AlertTimeUnit Days
            # These don't exist yet :(
            # -DownloadFromInternet $False `
            # -DownloadFromMicrosoftUpdate $True `

            Write-Host "Created deployment for" $CMAutoDeploymentRuleDeployment.CollectionName

            $Count++
        }
    }
}