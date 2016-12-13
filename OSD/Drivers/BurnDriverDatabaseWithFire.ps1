$drivers = Get-CMDriver

ForEach ($driver in $drivers)
{
    Remove-CMDriver -Name $driver.LocalizedDisplayName -Force
    Write-Host "Removing driver: $driver.LocalizedDisplayName"
}

$CMCategories = $CMCategories = Get-CMCategory -CategoryType "DriverCategories"

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
