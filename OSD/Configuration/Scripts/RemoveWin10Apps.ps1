########################################
# Remove Windows 10 Modern Apps (System)
########################################

# To find app names use: 
# Get-AppxProvisionedPackage -online  | Select DisplayName, PackageName

$appxpackages = ('Messaging', 'OneNote', 'OneConnect', 'SkypeApp', 'XboxApp')
 
ForEach($package in $appxpackages)
{
    try{
	    $packagenames=(Get-AppxProvisionedPackage -online | ?{$_.DisplayName -like '*' + $package + '*'}).PackageName
	    
	    ForEach ($packagename in $packagenames)
	    {
		    DISM /online /remove-provisionedappxpackage /packagename:$packagename
	    }
    }
    catch
    {
	    # Do nothing
	    Write-Host "Critical error removing package: "
	    Write-Host $package
    }
}
 
