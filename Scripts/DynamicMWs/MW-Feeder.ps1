#Point at the script to Remove the current MWs
$RemoveWindows = "$PSScriptRoot\Remove-CMMaintenanceWindow.ps1"

#Point at the script to Add the new MWs
$CMMaintenance = "$PSScriptRoot\New-CMMaintenanceWindow.ps1"

#Remove existing maintenance windows with the Remove-CMMantenanceWindow.ps1
Write-Host "Removing existing Maintenance Windows"
Start-Process -FilePath powershell.exe -ArgumentList "-file $RemoveWindows" -Wait
Write-Host "Maintenance Windows Removed" -ForegroundColor Green

#Import the CSV file containing the new MW information, and their intended targets
Write-Host "Applying new Maintenance Windows"
$Windows = Import-Csv "$PSScriptRoot\Window_Source.csv" #If you use a different CSV name, make sure to change it here!

#Loop through the Collections listed in the CSV, and create a MW based on the specifications on each of the Collections
ForEach($Line in $Windows) {
    $SiteCode = "CON" #Sitecode
    $SiteServer = "configmgr" #Server name doesn't need to be FQDN
    $CollectionID = $line.CollectionID.Trim() #The Unique collection ID
    $HourDuration = $line.HourDuration.Trim() #Number of hours to open the window.  24 limitation imposed by SCCM
    $MinuteDuration = $line.MinuteDuration.Trim() #Limited to 59 minutes. Anything over will add one hour and all else will be ignored. Ex: 61 = 1 hour, no minutes
    $MaintenanceWindowName = $line.Patch_Bucket.Trim() #The name of the MW for ease of
    $AddDays = $line.PlusDays.Trim() #Based on Patch Tuesday. E.g.: +6 = Monday, +11 = Saturday, etc… Negative values do work.  -1 = Monday before Patch Tuesday
    $StartHour = $line.StartHour.Trim() #24 hour format. Cannot exceed a value of 23. Must use "19", not "1900"
    $StartMinute = $line.StartMinute.Trim() #Limited to 59 minutes. Anything over will add one hour and all else will be ignored. Ex: 61 = 1 hour, no minutes

    #Add new MW, via Add-CMMaintenanceWindow.ps1, with the variables above pulled from the CSV
    Write-Host "Processing"$MaintenanceWindowName
    Start-Process -FilePath powershell.exe -ArgumentList "-file $CMMaintenance -SiteCode $SiteCode -MaintenanceWindowName ""$MaintenanceWindowName"" -AddMaintenanceWindowNameMonth -CollectionID $collectionid -PatchTuesday -adddays $adddays -currentmonth -StartHour $StartHour -StartMinute $StartMinute -HourDuration $HourDuration -MinuteDuration $MinuteDuration -siteserver $siteserver" -NoNewWindow -Wait

}