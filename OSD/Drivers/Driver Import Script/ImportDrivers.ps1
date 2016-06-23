Param(
	[string]$serverName = "X01337AA00100V.umpq.umpquabank.com"
	,[string]$CMSite = "UB1"
	,[string]$driverStore = "\\X01337AA00100V.umpq.umpquabank.com\Source$\OSD\Drivers"
	,[string]$CMPackageSource = "\\X01337AA00100V.umpq.umpquabank.com\Source$\OSD\Driver Packages"
	,[bool]$VerboseLogging = $false
)

#Logging settings
[bool]$Global:Verbose = [System.Convert]::ToBoolean($VerboseLogging)
$Global:LogFile = "FileSystem::" + $PSScriptRoot + "\DriverImport.log"
$Global:MaxLogSizeInKB = 10240
$Global:ScriptStatus = 'Success'
$LogItModule = $PSScriptRoot + "\Module_LogIt"

#Import modules
Import-Module -Name "ConfigurationManager.psd1"
Import-Module FileSystem::$LogItModule

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

	if (Test-Connection -quiet -computer $sccmServer)
	{
		Set-Location -Path $sccmSiteCode
		LogIt -message ("Successfully connected to: " + $sccmServer) -component "New-SCCMConnection()" -type "Info" -LogFile $LogFile
		#Write-Host "Successfully connected to: " $sccmServer
	}
	else
	{
		LogIt -message ("Failed to connect to: " + $sccmServer) -component "New-SCCMConnection()" -type "Error" -LogFile $LogFile
		#Write-Host "Failed to connect to: " $serverName
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
		
			$CMPackage = New-CMDriverPackage -Name $PackageName -Path $CMPackageSource #-PackageSourceType StorageDirect
			LogIt -message ("Created new driver package: " + $($PackageName)) -component "SDS-ProcessPackage()" -type "Info" -LogFile $LogFile
			#Write-Host "Created new driver package $($PackageName)"
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
	LogIt -message ("Importing driver :" + $driverPath) -component "SDS-ImportDriver" -type "Verbose" -LogFile $LogFile
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

#New-SCCMConnection -serverName "X01337AA00100V.umpq.umpquabank.com" -siteCode "UB1"
#Import-SCCMDriverStore -driverStore "\\X01337AA00100V.umpq.umpquabank.com\Source$\OSD\Drivers" -CMPackageSource "\\X01337AA00100V.umpq.umpquabank.com\Source$\OSD\Driver Packages"
# SIG # Begin signature block
# MIIOogYJKoZIhvcNAQcCoIIOkzCCDo8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUMeLnP8VTP23yh6OFloyadLHa
# viKgggwyMIIGEzCCBPugAwIBAgIKdTwoJwACAACDHzANBgkqhkiG9w0BAQUFADBJ
# MRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxGTAXBgoJkiaJk/IsZAEZFglVbXBxdWFu
# ZXQxFTATBgNVBAMTDFBEWC1DQS1JU1NVRTAeFw0xNDAyMTMwMTMwNThaFw0xNjEx
# MjExODM2MTVaMB4xHDAaBgNVBAMTE1VtcHF1YSBDb2RlIFNpZ25pbmcwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDSpeI1x0ooSC71cPWGbIWEvdjVRRei
# zNLaH0E4GHTaSwwiVZCydyi6Am7/TGH19HwvGlUdIFk4on1e2eVsFswD40QkEuEx
# j3702U1fisVrWoa1Dbnw9NxS1WHgKMDnUUjctLpGo+RDkojl1bEfS01sn9pGPWze
# wKV4OsDatj9TaRgO8sKHvZh4wF1ud5jzg7IO90I5bdiiBPwVobYYBj/SZOcZVuty
# V3u3v1tzwHdLG6O3UpZiVufOZKHPnV+o5TxxRVB+4UryxI/fo2e8kRl68Mklgt/f
# iu4/MclnFqZGVmYztmJBC5DRhsKvfiVerVF/e8dwi6oqkHRrxNg7PuOzAgMBAAGj
# ggMmMIIDIjA9BgkrBgEEAYI3FQcEMDAuBiYrBgEEAYI3FQiH0IV3gruhbYepiTiH
# 28oDgYOCBoF769QdgsaQfwIBZAIBAzALBgNVHQ8EBAMCB4AwHQYDVR0OBBYEFEdn
# NtjFxIGsA4qJGWC9v6+yOV9SMB8GA1UdIwQYMBaAFJ8Exz/UNFzDElUJsIFHoup8
# DUzdMIIBHwYDVR0fBIIBFjCCARIwggEOoIIBCqCCAQaGgb9sZGFwOi8vL0NOPVBE
# WC1DQS1JU1NVRSgyKSxDTj1QRFgtQ0EtSVNTVUUsQ049Q0RQLENOPVB1YmxpYyUy
# MEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9
# VW1wcXVhbmV0LERDPWxvY2FsP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFz
# ZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludIZCaHR0cDovL3BkeC1j
# YS1pc3N1ZS51bXBxdWFuZXQubG9jYWwvQ2VydEVucm9sbC9QRFgtQ0EtSVNTVUUo
# MikuY3JsMIIBMQYIKwYBBQUHAQEEggEjMIIBHzCBrwYIKwYBBQUHMAKGgaJsZGFw
# Oi8vL0NOPVBEWC1DQS1JU1NVRSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1VbXBxdWFuZXQs
# REM9bG9jYWw/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmlj
# YXRpb25BdXRob3JpdHkwawYIKwYBBQUHMAKGX2h0dHA6Ly9wZHgtY2EtaXNzdWUu
# dW1wcXVhbmV0LmxvY2FsL0NlcnRFbnJvbGwvUERYLUNBLUlTU1VFLlVtcHF1YW5l
# dC5sb2NhbF9QRFgtQ0EtSVNTVUUoMikuY3J0MDwGA1UdEQQ1MDOgMQYKKwYBBAGC
# NxQCA6AjDCF1bXBxdWFjb2Rlc2lnbmluZ0BVbXBxdWFuZXQubG9jYWwwDQYJKoZI
# hvcNAQEFBQADggEBAIgU/hT5h85mcF9yI+QETfHbiP9xTsJNMGyjUsHwgcshFTLt
# Fog7g1ZMpYC5bUjmnGjB1num0oZvKrr/fl10xHO4RQH6+xiHlj/btexrw+nv0BOU
# 8VvyPoQx7tukUFyiE/0eAf8UV8RPhiCv/SNSJrRb+wi0Ai90wg5VhceIpijRmsJ8
# r5N0XObAHjv9um+PCVjClP5O5mMujHn0ifSuizSwyutpA0TXwYilwYhC3WhW8ENl
# qPfM+jNa+ReKfh8C1fV0nWl8uCWB0xau9Us8nHiR5AJrwexNf0XDZdvGH3UN+VB4
# CJngJH7JcQwgBkDVO8kVZAW0XSQJxxvaW3X1vlwwggYXMIID/6ADAgECAgoq0IH0
# AAAAAAAJMA0GCSqGSIb3DQEBBQUAMFUxCzAJBgNVBAYTAlVTMRQwEgYDVQQKEwtV
# bXBxdWEgQmFuazEUMBIGA1UECxMLVW1wcXVhIEJhbmsxGjAYBgNVBAMTEVVtcHF1
# YW5ldCBSb290IENBMB4XDTEzMTEyMTE4MjYxNVoXDTE2MTEyMTE4MzYxNVowSTEV
# MBMGCgmSJomT8ixkARkWBWxvY2FsMRkwFwYKCZImiZPyLGQBGRYJVW1wcXVhbmV0
# MRUwEwYDVQQDEwxQRFgtQ0EtSVNTVUUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQCUndfocJJrsJvq030nbZu0r5kgQRqsCBT3iPRuYQUo/Fj1/HtnOygI
# b2ICmJPw/rCXoF3Q2YmKJootMc9yHtk1ccoKygG3b8eBS7fODoF7mNngqLSBKUqO
# /+8i+X0V8qqVrMAGkJxJlhksYwoigSUgkyZLzYXJDmvlAVsMJwImnDIBsAxZS3ly
# +583aUunr+rkrejSLDMC2+ykccu9z9mi2srh5EWuhGrDF1CGNBAtaC0hGBUigvlL
# Oj3/hD7hKQ9mHDs2wJlmQhiYOUcn3L8V2O7NmCqACw7ZU6DwY7tGu73/PeOkQ/AS
# MCInnUG1wD2hgVLPTgtbY8PV9hgxtuaPAgMBAAGjggHzMIIB7zAPBgNVHRMBAf8E
# BTADAQH/MB0GA1UdDgQWBBSfBMc/1DRcwxJVCbCBR6LqfA1M3TALBgNVHQ8EBAMC
# AYYwEgYJKwYBBAGCNxUBBAUCAwIAAjAjBgkrBgEEAYI3FQIEFgQUSNR5zJi/NgZI
# ITyLctIuADil9/QwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwHwYDVR0jBBgw
# FoAUC6YAioIFhNuzaaL2FdYgJ1vSyCIwgYEGA1UdHwR6MHgwdqB0oHKGOWh0dHA6
# Ly9wZHgtY2Etcm9vdDAxL0NlcnRFbnJvbGwvVW1wcXVhbmV0JTIwUm9vdCUyMENB
# LmNybIY1ZmlsZTovL1BEWC1DQS1ST09UMDEvQ2VydEVucm9sbC9VbXBxdWFuZXQg
# Um9vdCBDQS5jcmwwgbYGCCsGAQUFBwEBBIGpMIGmMFMGCCsGAQUFBzAChkdodHRw
# Oi8vcGR4LWNhLXJvb3QwMS9DZXJ0RW5yb2xsL1BEWC1DQS1ST09UMDFfVW1wcXVh
# bmV0JTIwUm9vdCUyMENBLmNydDBPBggrBgEFBQcwAoZDZmlsZTovL1BEWC1DQS1S
# T09UMDEvQ2VydEVucm9sbC9QRFgtQ0EtUk9PVDAxX1VtcHF1YW5ldCBSb290IENB
# LmNydDANBgkqhkiG9w0BAQUFAAOCAgEAgURzERD2aBItPlynYU3MLh4OB22IPYwf
# OX0fPe44i2UGHew/JwJfVWJDMG2YBU7HiECDDpwbvJNgRY/GFSoLpedMTrdVRX3J
# 2C/XSHOMifKolWaDbHfAVc4xmyzwv1eys3bDlvoz7nG58hfR4Ks6ZhqmfIzqlqRr
# 2Yln/gJ0JI5JaAoK5/TprSKAmuF2IF8s7ZCQ8bjir27rSFvFaw3Ppmt6UBErUFd6
# kK+ddyVvIsjL11Ivb5VyEj8G0wwaJOjjbMjqmGzq8TOg1Yi8Fh3SVQatsmSGkxKB
# MUk7QdtgZLWg0DqnsLDM44aaoIP6QPsKWBHDFfNEval4UKL4EWxkDMaybmzW30Ai
# 6DvihWapNrIPWn43oGpbQhnhjgdc27ECI4UoF50pWieSZc/2l3o8phrbs+snzNq9
# rxibHljS5Sc8O9IG026vcz/uydskEJVEDbSUbjzbUPKIa8BC2X5eWuzO2UpPeZok
# mpfQ/jxtKzfibcXe3GLNmzshJtfHuA9ejeJcl/VPDyxlorL2durGAcmgj2mSsvgx
# 1wBTh2+aJXvHSMBDixxgrdYvt1Ss6Xw7+WC69vmRbdYeMnQyBd+WXWaFCqet50+G
# gEKhO5Drk9t2lBO5rauqg8NAdx3h7liI6X3qKZ1sFFo2SxVGcVAob4fyWo678r+Q
# GlullckyzoYxggHaMIIB1gIBATBXMEkxFTATBgoJkiaJk/IsZAEZFgVsb2NhbDEZ
# MBcGCgmSJomT8ixkARkWCVVtcHF1YW5ldDEVMBMGA1UEAxMMUERYLUNBLUlTU1VF
# Agp1PCgnAAIAAIMfMAkGBSsOAwIaBQCgWjAYBgorBgEEAYI3AgEMMQowCKACgACh
# AoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMCMGCSqGSIb3DQEJBDEWBBR4
# lsUDg1D3YI7A7zNnnV/cBVu4qjANBgkqhkiG9w0BAQEFAASCAQBCXUu/g0TXS8Kd
# ysa2+bfeCVjQ63ALxl/Rw5xQPN7X1ci07QFFgsCU2x/XDNjha6af7YG0HK/su53N
# PijIF7rr8YIRP9CYM2l05fNWkTl9i1x+hRsmW4oeGl3y9M8kw5RDYZ68GwR17SF8
# 4EJ8iAhoRqHWDrrHbZjjxzXKTWdEwbAPwTxTElYGU7I+xHiSYkKGSjq3qexy11jL
# Nb/jhB3YojL+/nI+FO3ZntFAawrBBXJ9ThNer/wqJ+GQFCUT+dRX+S6ylD6k1BRe
# TVv5uynXRiuqv9szUJb+RwKVcnQuTD+VSxtap3DU3OCYShDysa/VmkHSGpsaqkuW
# bp4SabFj
# SIG # End signature block
