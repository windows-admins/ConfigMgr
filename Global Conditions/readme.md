# Global Condition scripts

Run the appropriate script to add the GCs described. These scripts require the Configuration Manager cmdlets
([see here](https://docs.microsoft.com/en-us/powershell/sccm/overview?view=sccm-ps#using-the-configuration-manager-cmdlets)), running them from a machine with the console installed is enough.

## [BIOS version](BIOSVersion.ps1)

Return the device's BIOS version as a version number, so that the GC can accurately do comparisons.


## [GCs for all models in CM](Models.ps1)

Conditions are created for each device model known to CM, as boolean "The computer's model is blah: true/false"
conditions for ease of use.

If you just want a query to return the device's model, try
```powershell
New-CMGlobalConditionWqlQuery -Name "Model" -Description "Model" -DeviceType Windows -Class Win32_ComputerSystem -Property Model -DataType String
```


## [GCs for all manufacturers in CM](Manufacturers.ps1)

Conditions are created for each device manufacturer known to CM, again as boolean conditions.

To just return the device's manufacturer, use:
```powershell
New-CMGlobalConditionWqlQuery -Name "Manufacturer" -Description "Manufacturer" -DeviceType Windows -Class Win32_ComputerSystem -Property Manufacturer -DataType String
```
