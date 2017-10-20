########################################
# Remove Windows 10 Modern Apps (System)
########################################

# To find app names use: 
# Get-AppxProvisionedPackage -online  | Select DisplayName, PackageName


$appxpackages = (
	'3DBuilder',
	'BingFinance',
	'BingSports',
	'CommsPhone',
	'ConnectivityStore',
	'GetHelp',
	'Getstarted',
	'HaloCamera',
	'HaloItemPlayerApp',
	'HaloShell',
	'Messaging',
	'Microsoft3DViewer',
	'MicrosoftOfficeHub',
	'MicrosoftSolitaireCollection',
	'Office.Sway',
	'OneConnect', 
	'OneNote', 
	'People',
	'Print3D',
	'SkypeApp', 
	'WindowsFeedbackHub',
	'WindowsPhone',
	'Xbox.TCUI',
	'XboxApp',
	'ZuneMusic',
	'ZuneVideo',
	'windowscommunicationsapps'
)
 
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
 
