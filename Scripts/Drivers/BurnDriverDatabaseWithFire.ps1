Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" # Import the ConfigurationManager.psd1 module 

$drivers = Get-CMDriver

ForEach ($driver in $drivers)
{
Remove-CMDriver -InputObject $driver -Force
Write-Host "Removing driver: $($driver.LocalizedDisplayName)"

}

$CMCategories = $CMCategories = Get-CMCategory -CategoryType "DriverCategories"

ForEach ($CMCategory in $CMCategories)
{
    Remove-CMCategory -InputObject $CMCategory -Force
    Write-Host "Removing driver category: $($CMCategory.LocalizedCategoryInstanceName)"
}

$CMDriverPackages = Get-CMDriverPackage

ForEach ($CMDriverPackage in $CMDriverPackages)
{
    Remove-CMDriverPackage -InputObject $CMDriverPackage -Force
    Write-Host "Removing driver package: $($CMDriverPackage.Name)"
}
