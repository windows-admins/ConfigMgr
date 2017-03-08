Param(
	[string]$serverName = "SERVER.fqdn.com"
	,[string]$CMSite = "P01"
	,[string]$driverStore = "\\SERVER.fqdn.com\Source$\OSD\Drivers"
	,[string]$CMPackageSource = "\\SERVER.fqdn.com\Source$\OSD\Driver Packages"
    ,[string]$CMCmdletLibrary = "ConfigurationManager.psd1"
	,[bool]$VerboseLogging = $false
)

#Logging settings
[bool]$Global:Verbose = [System.Convert]::ToBoolean($VerboseLogging)
$Global:LogFile = "FileSystem::" + $PSScriptRoot + "\DriverImport.log"
$Global:MaxLogSizeInKB = 10240
$Global:ScriptStatus = 'Success'
$LogItModule = $PSScriptRoot + "\Module_LogIt"

#Import modules
Import-Module FileSystem::$LogItModule
if (Test-Path -Path "FileSystem::$CMCmdletLibrary")
{
    Import-Module -Name $CMCmdletLibrary
}
else
{
    LogIt -message ("Cannot find SCCM Cmdlet Library: " + $CMCmdletLibrary) -component "init()" -type "Error" -LogFile $LogFile
    Return
}

# Test to make sure folders exist
if (Test-Path -Path "FileSystem::$driverStore")
{
    LogIt -message ("Driver store exists: " + $driverStore) -component "init()" -type "Verbose" -LogFile $LogFile
}
else
{
    LogIt -message ("Cannot find driver store: " + $CMPackageSource) -component "init()" -type "Error" -LogFile $LogFile
    Return
}

if (Test-Path -Path "FileSystem::$CMPackageSource")
{
    LogIt -message ("Driver package source exists: " + $CMPackageSource) -component "init()" -type "Verbose" -LogFile $LogFile
}
else
{
    LogIt -message ("Cannot find driver package source: " + $CMPackageSource) -component "init()" -type "Error" -LogFile $LogFile
    Return
}

Function New-SCCMConnection {
	[CmdletBinding()]
	PARAM
	(
		[Parameter(Position=1)] $serverName,
		[Parameter(Position=2)] $siteCode
	)
	
	# Clear the results from any previous execution
	Clear-Variable -name "sccmServer" -Scope "Global" -Force -errorAction SilentlyContinue
	Clear-Variable -name "sccmSiteCode" -Scope "Global" -Force -errorAction SilentlyContinue

	# If the $serverName is not specified, use local host
	if ($serverName -eq $null -or $serverName -eq "")
	{
		$serverName = $env:computername
	}

	$global:sccmServer = $serverName
	$global:sccmSiteCode = $siteCode + ":"


	# Make sure we can get a connection
    try
    {
        Set-Location -Path $sccmSiteCode
        LogIt -message ("Successfully connected to: " + $sccmServer) -component "New-SCCMConnection()" -type "Info" -LogFile $LogFile
    }
    catch
    {
        LogIt -message ("Failed to connect to: " + $sccmServer) -component "New-SCCMConnection()" -type "Error" -LogFile $LogFile
        Exit
    }

}

Function Import-SCCMDriverStore
{
	PARAM
	(
		[Parameter(Position=1)] $driverStore,
		[Parameter(Position=2)] $CMPackageSource,
		[switch] $cleanup
	)
	
	if ($cleanup)
	{
		$currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )
		if (!$currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ))
		{
			LogIt -message ("You need to run Powershell as Administrator.") -component "Import-SCCMDriverStore()" -type "Error" -LogFile $LogFile
			#Write-Host "You need to run Powershell as Administrator."
			return;
		}
	}

	LogIt -message ("Starting Importing Driver Store: " + $($driverStore)) -component "Import-SCCMDriverStore()" -type "Info" -LogFile $LogFile
	#Write-Host "Starting Importing Driver Store: $($driverStore)"
	
	Get-ChildItem "FileSystem::$driverStore" | ? {$_.psIsContainer -eq $true} | % {
		$global:CurrentDepth = 1
		SDS-ProcessFolder $_
	}
}

Function SDS-ProcessFolder
{
	PARAM
	(
		[Parameter(Position=1)] $path
	)
	
	$FolderPath = $path.FullName.Substring($DriverStore.Length+1, $path.FullName.Length-($DriverStore.Length+1))
	$FolderName = $path.FullName.Substring($DriverStore.Length+1, $path.FullName.Length-($DriverStore.Length+1))
	LogIt -message ("Processing Folder: " + $($FolderName)) -component "SDS-ProcessFolder()" -type "Verbose" -LogFile $LogFile
	#Write-Host "Processing Folder: $($FolderName)"
	
	$FullPath = $path.FullName
	LogIt -message ("Folder path: " + $FullPath) -component "SDS-ProcessFolder()" -type "Verbose" -LogFile $LogFile
	#Write-Host "Folder path: $FullPath"
	
	Get-ChildItem -Path "FileSystem::$FullPath" | ? {$_.psIsContainer -eq $true} | % {
		$CurrentDepth = 2
		$FolderName = $_.FullName.Substring($DriverStore.Length+1, $_.FullName.Length-($DriverStore.Length+1))
		LogIt -message ("Processing Folder: " + $($FolderName)) -component "SDS-ProcessFolder()" -type "Verbose" -LogFile $LogFile
		#Write-Host "Processing Folder: $($FolderName)"
		$FullPathLevel2 = $_.FullName
		LogIt -message ("Folder path: " + $FullPath) -component "SDS-ProcessFolder()" -type "Verbose" -LogFile $LogFile
		#Write-Host "Folder path: $FullPathLevel2"
		Get-ChildItem -Path "FileSystem::$FullPathLevel2" | ? {$_.psIsContainer -eq $true} | % {
			$CurrentDepth = 3
			SDS-ProcessPackage $_ $FolderPath
		}
	}
}

Function SDS-ProcessPackage
{
	PARAM
	(
		[Parameter(Position=1)] $package
		,[Parameter(Position=2)] $folderPath
	)

	$PackageName = $package.FullName.Substring($DriverStore.Length+1, $package.FullName.Length-($DriverStore.Length+1))
	$PackageName = $PackageName.Replace("\","_")
    # Uncomment if you want to add a string to start/end of package
    #$PackageName = "D " + $PackageName + " P"
	
	LogIt -message ("Processing Driver Package: " + $($PackageName)) -component "SDS-ProcessPackage()" -type "Info" -LogFile $LogFile
	Write-Progress -Activity "Importing Drivers" -Status "Driver Package: $PackageName"
	#Write-Host "Processing Driver Package: $($PackageName)"
	$PackageFullPath = $package.FullName
	LogIt -message ("Driver package path: " + $PackageFullPath) -component "SDS-ProcessPackage()" -type "Verbose" -LogFile $LogFile
	#Write-Host "Driver package path: $PackageFullPath" 
	$PackageHash = Get-FolderHash $PackageFullPath
	If (Get-ChildItem "FileSystem::$PackageFullPath" -Filter "$($PackageHash).hash")
	{
		LogIt -message ("No changes has been made to this Driver Package. Skipping.") -component "SDS-ProcessPackage()" -type "Info" -LogFile $LogFile
		#Write-Host "No changes has been made to this Driver Package. Skipping."
	}
	Else
	{
		#Connect to SCCM provider
		Set-Location -Path $sccmSiteCode
		
		$CMCategory = Get-CMCategory -Name $PackageName -CategoryType "DriverCategories"
		if ($CMCategory -eq $null)
		{
			$CMCategory = New-CMCategory -Name $PackageName -CategoryType "DriverCategories"
			LogIt -message ("Created new driver category: " + $($PackageName)) -component "SDS-ProcessPackage()" -type "Info" -LogFile $LogFile
			#Write-Host "Created new driver category: $($PackageName)"
		}
		
		$CMPackage = Get-CMDriverPackage -Name $PackageName
		
		if ($CMPackage -eq $null)
		{
			LogIt -message ("Driver package missing for: " + $($PackageName)) -component "SDS-ProcessPackage()" -type "Verbose" -LogFile $LogFile
			#Write-Host "Driver package missing for $($PackageName)"
			#$CMPackageSource = "$($CMPackageSource)\$($folderPath)\$($PackageName)"
			$CMPackageSource = "$($CMPackageSource)\$($PackageName)"
			LogIt -message ("Driver Package Source Location: " + $CMPackageSource) -component "SDS-ProcessPackage()" -type "Verbose" -LogFile $LogFile
			#Write-Host "Driver Package Source Location: $CMPackageSource"

			if (Test-Path -Path "FileSystem::$CMPackageSource")
			{
				if((Get-Item -Path "FileSystem::$CMPackageSource" | %{$_.GetDirectories().Count + $_.GetFiles().Count}) -gt 0)
				{
					if ($cleanup)
					{
						LogIt -message ("Folder already exists, removing content: " + $CMPackageSource) -component "SDS-ProcessPackage()" -type "Warning" -LogFile $LogFile
						#Write-Host "Folder already exists, removing content"
						dir $driverPackageSource | remove-item -recurse -force
					}
					else
					{
						LogIt -message ("Folder already exists, remove it manually: " + $CMPackageSource) -component "SDS-ProcessPackage()" -type "Error" -LogFile $LogFile
						#Write-Host "Folder already exists, remove it manually."
						return
					}
				}
				LogIt -message ("Driver package folder already exists") -component "SDS-ProcessPackage()" -type "Verbose" -LogFile $LogFile
				#Write-Host "Driver package folder already exists"
			}
			else
			{
				$null = New-Item "FileSystem::$CMPackageSource" -type directory
				LogIt -message ("Created driver package folder") -component "SDS-ProcessPackage()" -type "Verbose" -LogFile $LogFile
				#Write-Host "Created driver package folder"
			}
		
            try
            {
			    $CMPackage = New-CMDriverPackage -Name $PackageName -Path $CMPackageSource #-PackageSourceType StorageDirect
			    LogIt -message ("Created new driver package: " + $($PackageName)) -component "SDS-ProcessPackage()" -type "Info" -LogFile $LogFile
			    #Write-Host "Created new driver package $($PackageName)"
            }
            catch
            {
                LogIt -message ("Failed to create driver package. Exiting. Error: " + $($_.ToString())) -component "SDS-ProcessPackage()" -type "Error" -LogFile $LogFile
                Exit
            }
		}
		else
		{
			#Grab existing drivers for this package. This will save us time later if they already exist.
			$ExistingDrivers = Get-CMDriver -DriverPackage $CMPackage
			LogIt -message ("Existing driver package " + $($PackageName) + " (" + $($CMPackage.PackageID) + ") retrieved.") -component "SDS-ProcessPackage()" -type "Info" -LogFile $LogFile
			#Write-Host "Existing driver package $($PackageName) ($($CMPackage.PackageID)) retrieved." 
		}
		
		$DriverFiles = Get-ChildItem "FileSystem::$PackageFullPath" -Filter *.inf -File -recurse
		Clear-Variable -name "Count" -Force -errorAction SilentlyContinue
		
		ForEach ($DriverFile in $DriverFiles)
		{
			$Count++
			$CurrentCount = "[$Count/" + $DriverFiles.Count + "] Driver: $driverINF"
			$driverINF = split-path $DriverFile.FullName -leaf
			Write-Progress -Activity "Importing Drivers" -Status "Driver Package: $PackageName" -CurrentOperation $CurrentCount
			SDS-ImportDriver $DriverFile $CMCategory $CMPackage $ExistingDrivers
		}
		
		Get-ChildItem "FileSystem::$PackageFullPath" -Filter "*.hash"  | Remove-Item 
		
		$HashFile = "$($PackageFullPath)\$($PackageHash).hash"
		$null = New-Item "FileSystem::$HashFile" -type file 
	}
}

Function SDS-ImportDriver
{
	PARAM
	(
		[Parameter(Position=1)] $dv
		,[Parameter(Position=2)] $category
		,[Parameter(Position=3)] $package
		,[Parameter(Position=4)] $ExistingDrivers
	)

	$driverPath = $dv.FullName
	LogIt -message ("Importing driver: " + $driverPath) -component "SDS-ImportDriver" -type "Verbose" -LogFile $LogFile
	#Write-Host "Importing driver $driverPath"

        $driverINF = split-path $dv.FullName -leaf 
        $driverPath = split-path $dv.FullName
        
	$ExistingDriver = $ExistingDrivers  | Where-Object {$_.ContentSourcePath -eq $driverPath -and $_.DriverINFFile -eq $driverINF}


	If ($ExistingDriver)
	{
		LogIt -message ("Driver (" + $driverINF + ") already exists. Skipping.") -component "SDS-ImportDriver" -type "Verbose" -LogFile $LogFile
		#Write-Host "Driver ($driverINF) already exists. Skipping."
	}
	Else
	{
        
		$DriverImport = Import-CMDriver -UncFileLocation $dv.FullName -AdministrativeCategory $category -DriverPackage $package -EnableAndAllowInstall $true -ImportDuplicateDriverOption "AppendCategory"

		If($DriverImport)
		{
			LogIt -message ("Imported driver (" + $driverINF + ") successfully.") -component "SDS-ImportDriver" -type "Verbose" -LogFile $LogFile
			#Write-Host "Imported driver ($driverINF) successfully"
			Return
		}
		Else
		{
			LogIt -message ("Error importing driver: " + $dv.FullName) -component "SDS-ImportDriver" -type "Error" -LogFile $LogFile
			#Write-Host "Error importing driver $driverPath"
			Return
		}
	}
}

Function Get-ContentHash
{
	Param (
		$File,
		[ValidateSet("sha1","md5")]
		[string]$Algorithm="md5"
	)

	$content = "$($file.Name)$($file.Length)"
	$algo = [type]"System.Security.Cryptography.md5"
	$crypto = $algo::Create()
	$hash = [BitConverter]::ToString($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($content))).Replace("-", "")
	$hash
}

Function Get-FolderHash
{
	Param (
		[string]$Folder=$(throw("You must specify a folder to get the checksum of.")),
		[ValidateSet("sha1","md5")]
		[string]$Algorithm="md5"
	)

	Get-ChildItem "FileSystem::$Folder" -Recurse -Exclude "*.hash" | % { $content += Get-ContentHash $_ $Algorithm }


	$algo = [type]"System.Security.Cryptography.$Algorithm"
	$crypto = $algo::Create()
	$hash = [BitConverter]::ToString($crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($content))).Replace("-", "")

	$hash
}

########################################
#Start Main code block
########################################

$DateTime = Get-Date
LogIt -message (" ") -component " " -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component " " -type "Info" -LogFile $LogFile
LogIt -message ($DateTime) -component " " -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component " " -type "Info" -LogFile $LogFile
LogIt -message (" ") -component " " -type "Info" -LogFile $LogFile

New-SCCMConnection -serverName $serverName -siteCode $CMSite
Import-SCCMDriverStore -driverStore $driverStore -CMPackageSource $CMPackageSource

