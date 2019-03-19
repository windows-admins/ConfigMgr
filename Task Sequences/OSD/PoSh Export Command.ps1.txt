Get-CMTaskSequence -Name "OSD - Modular OSD" | Export-CMTaskSequence -ExportFilePath "C:\Temp\Modular OSD Export\ModularOSD.zip" -WithDependence $true -WithContent $true
