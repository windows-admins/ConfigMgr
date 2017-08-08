########################################
# Remove Windows 10 Modern Apps (System)
########################################

# To find app names use: 
# Get-AppxProvisionedPackage -online  | Select DisplayName, PackageName

$appxpackages = ('Messaging', 'OneNote', 'OneConnect', 'SkypeApp', 'XboxApp')
 
Foreach($package in $appxpackages){
    try{
	    $packagename=(Get-AppxProvisionedPackage -online | ?{$_.DisplayName -like '*' + $package + '*'}).PackageName
	    DISM /online /remove-provisionedappxpackage /packagename:$packagename
    }
    catch{
	    # Do nothing
	    Write-Host "Critical error removing package: "
	    Write-Host $package
    }
}
 