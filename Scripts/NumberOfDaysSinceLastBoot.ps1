$OBJ_OperatingSystem = Get-WmiObject -Class Win32_OperatingSystem
$BootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($OBJ_OperatingSystem.LastBootUpTime)
$LocalTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($OBJ_OperatingSystem.LocalDateTime)
$TimeSpan = New-TimeSpan -Start $BootTime -End $LocalTime
Write-Output ($TimeSpan.Days).ToString()