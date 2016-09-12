$drivers = Get-CMDrivers

ForEach ($driver in $drivers)
{
    Remove-CMDrivers -Name $driver.LocalizedDisplayName -Force
    Write-Host "Removing driver: $driver.LocalizedDisplayName"
}

$CMCategories = Get-CMCategory -Name $PackageName -CategoryType "DriverCategories"

ForEach ($CMCategory in $CMCategories)
{
    Remove-CMCategory -Name $CMCategory.LocalizedCategoryInstanceName -Force
    Write-Host "Removing driver category: $CMCategory.LocalizedCategoryInstanceName"
}

$CMDriverPackages = Get-CMDriverPackage

ForEach ($CMDriverPackage in $CMDriverPackages)
{
    Remove-CMDriverPackage -Name $CMDriverPackage.Name -Force
    Write-Host "Removing driver package: $CMDriverPackage.Name"
}