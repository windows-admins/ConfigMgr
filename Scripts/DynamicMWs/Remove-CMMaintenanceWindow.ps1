# Uncomment the line below if running in an environment where script signing is 
# required.
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Site configuration
$SiteCode = "CON" # Site code 
$ProviderMachineName = "configmgr.contoso.com" # SMS Provider machine name

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

#Import the CSV file containing the new MW information, and their intended targets
$Windows = Import-Csv "$PSScriptRoot\Window_Source.csv"

#Loop through the Collections listed in the CSV, and delete all MW's found
ForEach($Line in $Windows) {
$CollectionID = $Line.collectionid
$CollectionWindows = Get-CMMaintenanceWindow -CollectionID $CollectionID
    
    #Remove any and all MWs found on the collection 
    Foreach($WindowName in $CollectionWindows) {
        If($WindowName) {
        $LoopWindowName = $WindowName.Name
        Write-Host "Removing " $LoopWindowName
        Remove-CMMaintenanceWindow -CollectionID $CollectionID -Name $LoopWindowName -Force
        } Else {
        }
    }
}