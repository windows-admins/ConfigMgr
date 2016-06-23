Import-Module ConfigurationManager.psd1
cd UB1:
$stream = [System.IO.StreamWriter] "C:\Users\GabeBennett.adm\Downloads\e.csv"


function DTCleanPath($x)
{
	Write-Host "Application deployment type: " $x
	$DeploymentTypeName = Get-CMDeploymentType -ApplicationName $x 
 
	ForEach($DT in $DeploymentTypeName) 
	{
		#Write-Host "DT " $DT
		## Change the directory path to the new location 
		$DTSDMPackageXLM = $DT.SDMPackageXML 
		$DTSDMPackageXLM = [XML]$DTSDMPackageXLM 
    
		## Get Path for Apps with multiple DTs 
		$DTCleanPath = $DTSDMPackageXLM.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location[0]
	   
		## Get Path for Apps with single DT 
		IF($DTCleanPath -eq "\") 
		{ 
			$DTCleanPath = $DTSDMPackageXLM.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
		} 
	}
	#Write-Host "Returning: " $DTCleanPath
	Return $DTCleanPath
   
}

function AppSize($DeploymentPackage)
{
	$SumSourcePathSize = 0
	$TotalSourcePathSize = 0

	#Write-Host "Checking size for: " $DeploymentPackage.Name

	$SourcePaths = DTCleanPath($DeploymentPackage.Name)

	foreach ($SourcePath in $SourcePaths)
	{
		$SourcePath = $SourcePath -replace '\\\\X01337AA00100V.umpq.umpquabank.com\\Source\$', "A:"
		$SourcePath = $SourcePath -replace '\\\\X01337AA00100V\\Source\$', "A:"

		#Write-Host "Source Path: " $SourcePath

		$SourcePathSize = (Get-ChildItem $SourcePath -recurse | Measure-Object -property length -sum)
		$SumSourcePathSize = "{0:N2}" -f ($SourcePathSize.sum / 1KB)
		$SumSourcePathSize = $SumSourcePathSize -replace ',', ""
		$TotalSourcePathSize += $SumSourcePathSize
	}
	
	return $TotalSourcePathSize
}


function DriverSize($DeploymentPackage)
{
	$DriverPackages = Get-CMDriverPackage -Name $DeploymentPackage.Name

	foreach ($DriverPackage in $DriverPackages)
	{
		#Write-Host $DriverPackage.Name
		$SourcePath = $DriverPackage.PkgSourcePath -replace '\\\\X01337AA00100V.umpq.umpquabank.com\\Source\$', "A:"
		$SourcePath = $SourcePath -replace '\\\\X01337AA00100V\\Source\$', "A:"
	
		$SourcePathSize = (Get-ChildItem $SourcePath -recurse | Measure-Object -property length -sum)
		$SumSourcePathSize = "{0:N2}" -f ($SourcePathSize.sum / 1KB)
		$SumSourcePathSize = $SumSourcePathSize -replace ',', ""
	}

	Return $SumSourcePathSize
}

function UpdateSize($DeploymentPackage)
{
	$UpdatePackages = Get-CMSoftwareUpdateDeploymentPackage -Name $DeploymentPackage.Name

	foreach ($UpdatePackage in $UpdatePackages)
	{
		#Write-Host $UpdatePackage.Name
		$SourcePath = $UpdatePackage.PkgSourcePath -replace '\\\\X01337AA00100V.umpq.umpquabank.com\\Source\$', "A:"
		$SourcePath = $SourcePath -replace '\\\\X01337AA00100V\\Source\$', "A:"
	
		$SourcePathSize = (Get-ChildItem $SourcePath -recurse | Measure-Object -property length -sum)
		$SumSourcePathSize = "{0:N2}" -f ($SourcePathSize.sum / 1KB)
		$SumSourcePathSize = $SumSourcePathSize -replace ',', ""
	}

	Return $SumSourcePathSize
}

function LegacyPackageSize($DeploymentPackage)
{
	$LegacyPackages = Get-CMPackage -Name $DeploymentPackage.Name

	foreach ($LegacyPackage in $LegacyPackages)
	{
		#Write-Host $LegacyPackage.Name
		$SourcePath = $LegacyPackage.PkgSourcePath -replace '\\\\X01337AA00100V.umpq.umpquabank.com\\Source\$', "A:"
		$SourcePath = $SourcePath -replace '\\\\X01337AA00100V\\Source\$', "A:"
	
		$SourcePathSize = (Get-ChildItem $SourcePath -recurse | Measure-Object -property length -sum)
		$SumSourcePathSize = "{0:N2}" -f ($SourcePathSize.sum / 1KB)
		$SumSourcePathSize = $SumSourcePathSize -replace ',', ""
	}

	Return $SumSourcePathSize
}

Write-Host "Parsing Deployment Packages"
$DeploymentPackages = Get-CMDeploymentPackage -DistributionPointName "X01337AA00600V.UMPQ.UMPQUABANK.COM"

foreach ($DeploymentPackage in $DeploymentPackages)
{
	Write-Host $DeploymentPackage.Name

	Clear-Variable -Name ApplicationType
	Clear-Variable -Name TotalSourcePathSize

	Write-Host "Object Type: " $DeploymentPackage.ObjectType

	switch ($DeploymentPackage.ObjectType)
	{
		0
		{
			$ApplicationType = "Legacy Package"
			$TotalSourcePathSize = LegacyPackageSize($DeploymentPackage)
		}
		3
		{
			$ApplicationType = "Driver Package"
			$TotalSourcePathSize = DriverSize($DeploymentPackage)
		}
		5
		{
			$ApplicationType = "Update Package"
			$TotalSourcePathSize = UpdateSize($DeploymentPackage)
		}
		257
		{
			$ApplicationType = "Operating System Image"
			#$TotalSourcePathSize = UpdateSize($DeploymentPackage)
		}
		258
		{
			$ApplicationType = "Boot Image"
			#$TotalSourcePathSize = UpdateSize($DeploymentPackage)
		}
		512
		{
			$ApplicationType = "Application"
			$TotalSourcePathSize = AppSize($DeploymentPackage)
		}
		default
		{
			$ApplicationType = "Unknown type: " + $DeploymentPackage.ObjectType

		}
	}
	
	Write-Host "Deployment Package Type: " $ApplicationType "     Size" $TotalSourcePathSize

	$Line = $DeploymentPackage.PackageID + "," + $DeploymentPackage.ObjectID + "," + $ApplicationType + "," + $DeploymentPackage.Name + "," + $DeploymentPackage.SourceSize + "," + $TotalSourcePathSize 


	$stream.WriteLine($Line)

	
}


$stream.close()