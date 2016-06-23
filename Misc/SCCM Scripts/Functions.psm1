function Get-ApplicationFolder
{
	<#
	    .DESCRIPTION
            Gets the folder path that an application object lives in.
            We have to do this via WMI because there is no CM Powershell
            Library function to look this up.
        .PARAMETER CMSite
            CM site code
        .PARAMETER CMServer
            CM site server
        .PARAMETER App
            Application object
        .OUTPUTS
            Returns a string with application folder location
	    .EXAMPLE
            Get-ApplicationFolder 'ABC' 'SITESERVER.fqdn.com' $AppObject
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    [string]$CMSite,
	    [Parameter(Mandatory=$true)]
	    [string]$CMServer,
	    [Parameter(Mandatory=$true)]
	    $App
	)

    #$AppCI_UniqueID = $App.CI_UniqueID.Substring(0,$App.CI_UniqueID.Length-($App.CIVersion.Length+1))
    $temp = $App.CI_UniqueID.split("/")
    $AppCI_UniqueID = $temp[0] + "/" + $temp[1]

    $Query = "SELECT ContainerNodeID FROM SMS_ObjectContainerItem WHERE InstanceKey = '$AppCI_UniqueID'"
    $ContainerItem = Get-WmiObject -Namespace root/SMS/site_$($CMSite) -ComputerName $CMServer -Query $Query

    $ContainerNodeID = $ContainerItem.ContainerNodeID

    If ($ContainerNodeID)
    {
        While ($ContainerNodeID -ne '0')
        {
            $Query = "SELECT Name,ParentContainerNodeID FROM SMS_ObjectContainerNode WHERE ContainerNodeID = '$ContainerNodeID' AND SearchFolder = 0"
            $Container = Get-WmiObject -Namespace root/SMS/site_$($CMSite) -ComputerName $CMServer -Query $Query

            $ContainerPath = $Container.Name + "\" + $ContainerPath

            $ContainerNodeID = $Container.ParentContainerNodeID
        }
    }
    Else
    {
        $ContainerPath = "\"
    }

    Return $ContainerPath
}

function Get-CollectionFolder
{
	<#
	    .DESCRIPTION
            Gets the folder path that an collection object lives in.
            We have to do this via WMI because there is no CM Powershell
            Library function to look this up.
        .PARAMETER CMSite
            CM site code
        .PARAMETER CMServer
            CM site server
        .PARAMETER App
            Application object
        .OUTPUTS
            Returns a string with collection folder location
	    .EXAMPLE
            Get-CollectionFolder 'ABC' 'SITESERVER.fqdn.com' $CollectionObject
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    [string]$CMSite,
	    [Parameter(Mandatory=$true)]
	    [string]$CMServer,
	    [Parameter(Mandatory=$true)]
	    $Collection
	)

    $CollectionID = $Collection.CollectionID
    $Query = "SELECT ContainerNodeID FROM SMS_ObjectContainerItem WHERE InstanceKey = '$CollectionID'"
    $ContainerItem = Get-WmiObject -Namespace root/SMS/site_$($CMSite) -ComputerName $CMServer -Query $Query

    $ContainerNodeID = $ContainerItem.ContainerNodeID

    If ($ContainerNodeID)
    {
        While ($ContainerNodeID -ne '0')
        {
            $Query = "SELECT Name,ParentContainerNodeID FROM SMS_ObjectContainerNode WHERE ContainerNodeID = '$ContainerNodeID' AND SearchFolder = 0"
            $Container = Get-WmiObject -Namespace root/SMS/site_$($CMSite) -ComputerName $CMServer -Query $Query

            $ContainerPath = $Container.Name + "\" + $ContainerPath

            $ContainerNodeID = $Container.ParentContainerNodeID
        }
    }
    Else
    {
        $ContainerPath = "\"
    }

    Return $ContainerPath
}

function Remove-AllDeployments
{
	<#
	    .DESCRIPTION
            Removes the app from all collections.  We pass in a list of
            collections to search through, so this can be limited to a
            set number of collections.
        .PARAMETER App
            CM site code
        .PARAMETER DeviceCollections
            CM site server
        .PARAMETER UserCollections
            Application object
        .OUTPUTS
            Nothing
	    .EXAMPLE
            Remove-AllDeployments $AppObject $DeviceCollectionObjects $UserCollectionObjects
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $App,
        [Parameter(Mandatory=$true)]
	    $DeviceCollections,
        [Parameter(Mandatory=$true)]
	    $UserCollections
	)

    $SoftwareLibraryPrefix = 'Software Library - '
    $SxS_NamePrefix = '[SxS '
    $AppNameStringSearch = '*'+$App.LocalizedDisplayName+'*'

    ForEach ($Collection in $DeviceCollections)
    {
        #Remove direct app deployment and software library deployment
        If (($Collection.Name -eq $App.LocalizedDisplayName) -or $Collection.Name.StartsWith($SoftwareLibraryPrefix))
        {
            LogIt -message ("Removing deployment from device collection: " + $Collection.Name) -component "Remove-AllDeployments()" -type "Verbose" -LogFile $LogFile
            Remove-CMDeployment -ApplicationName $App.LocalizedDisplayName -CollectionName $Collection.Name -Force
        }

        #Remove SxS collection deployments
        If ($Collection.Name.StartsWith($SxS_NamePrefix) -and ($Collection.Name -like $AppNameStringSearch))
        {
            LogIt -message ("Removing deployment from device collection: " + $Collection.Name) -component "Remove-AllDeployments()" -type "Verbose" -LogFile $LogFile
            Remove-CMDeployment -ApplicationName $App.LocalizedDisplayName -CollectionName $Collection.Name -Force
        }
    }

    ForEach ($Collection in $UserCollections)
    {
        #Remove direct app deployment and software library deployment
        If (($Collection.Name -eq $App.LocalizedDisplayName) -or $Collection.Name.StartsWith($SoftwareLibraryPrefix))
        {
            LogIt -message ("Removing deployment from user collection: " + $Collection.Name) -component "Remove-AllDeployments()" -type "Verbose" -LogFile $LogFile
            Remove-CMDeployment -ApplicationName $App.LocalizedDisplayName -CollectionName $Collection.Name -Force
        }

        #Remove SxS collection deployments
        If ($Collection.Name.StartsWith($SxS_NamePrefix) -and ($Collection.Name -like $AppNameStringSearch))
        {
            LogIt -message ("Removing deployment from user collection: " + $Collection.Name) -component "Remove-AllDeployments()" -type "Verbose" -LogFile $LogFile
            Remove-CMDeployment -ApplicationName $App.LocalizedDisplayName -CollectionName $Collection.Name -Force
        }
    }
    
    Return
}

function Deploy-ApplicationtoCollection
{
	<#
	    .DESCRIPTION
            Deploys an application to a specific collection.
        .PARAMETER App
            Application object
        .PARAMETER CollectionName
            Name of collection (not the collection object)
        .PARAMETER Install
            If the deployment is for install or uninstall
        .PARAMETER DeployPurpose
            Whether the deployment is availible or required. Uninstall deployments are ALWAYS required.
        .PARAMETER Deployments
            Object from Get-CMDeployments. This will be used to search through to see if the application is already deployed.
        .OUTPUTS
            Nothing
	    .EXAMPLE
            Deploy-ApplicationtoCollection $AppObject $CollectionName 'Install' 'Required' $DeploymentObject
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $App,
	    [Parameter(Mandatory=$true)]
	    $CollectionName,
	    [Parameter(Mandatory=$true)]
        [ValidateSet("Install","Uninstall")] 
	    $Install,
	    [Parameter(Mandatory=$true)]
        [ValidateSet("Available","Required")] 
	    $DeployPurpose,
	    [Parameter(Mandatory=$true)]
        $Deployments
	)

    $DeploymentsforApplication = @($Deployments) -match $App.PackageID

    If ($DeploymentsforApplication.CollectionName -notcontains $CollectionName)
    {
        LogIt -message ("Deploying " + $App.LocalizedDisplayName + " to " + $CollectionName) -component "Deploy-ApplicationtoCollection()" -type "Verbose" -LogFile $LogFile
        $Return = Start-CMApplicationDeployment -CollectionName $CollectionName -Name $App.LocalizedDisplayName -AppRequiresApproval $false -DeployAction $Install -DeployPurpose $DeployPurpose -EnableMomAlert $false -RebootOutsideServiceWindow $false -UseMeteredNetwork $false -UserNotification DisplaySoftwareCenterOnly -Force -WarningAction SilentlyContinue
    }
    Else
    {
        LogIt -message ($App.LocalizedDisplayName + " is already deployed to " + $CollectionName) -component "Deploy-ApplicationtoCollection()" -type "Verbose" -LogFile $LogFile
    }

    Return
}

function Remove-ApplicationtoCollection
{
	<#
	    .DESCRIPTION
            Removes an application deployment from a specific collection.
        .PARAMETER App
            Application object
        .PARAMETER CollectionName
            Name of collection (not the collection object)
        .PARAMETER Deployments
            Object from Get-CMDeployments. This will be used to search through to see if the application is already deployed.
        .OUTPUTS
            Nothing
	    .EXAMPLE
            Deploy-ApplicationtoCollection $AppObject $CollectionName $DeploymentObject
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $App,
	    [Parameter(Mandatory=$true)]
	    $CollectionName,
	    [Parameter(Mandatory=$true)]
        $Deployments
	)

    $DeploymentsforApplication = @($Deployments) -match $App.PackageID

    If ($DeploymentsforApplication.CollectionName -contains $CollectionName)
    {
        LogIt -message ("Removing deployment of " + $App.LocalizedDisplayName + " from " + $CollectionName) -component "Remove-ApplicationtoCollection()" -type "Verbose" -LogFile $LogFile
        $Return = Remove-CMDeployment -ApplicationName $App.LocalizedDisplayName -CollectionName $CollectionName -Force
    }
    Else
    {
        LogIt -message ($App.LocalizedDisplayName + " is not deployed to " + $CollectionName) -component "Remove-ApplicationtoCollection()" -type "Verbose" -LogFile $LogFile
    }

    Return
}

function Create-Collection
{
	<#
	    .DESCRIPTION
            Creates a new collection and moves it to the desired location.  If collection already exists, just move it to the desired location.
        .PARAMETER CollectionName
            Name of new collection
        .PARAMETER FolderPath
            Path to the desired folder
        .PARAMETER Collections
            Object from Get-CMDeviceCollection or Get-CMUserCollection. This will be used to search through to see if the collection already exists.
        .PARAMETER CollectionType
            Device collection or user collection
        .OUTPUTS
            Collection object for the created/found collection
	    .EXAMPLE
           Create-Collection $App.LocalizedDisplayName $FolderPath $Collections 'Device'
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $CollectionName,
	    [Parameter(Mandatory=$true)]
	    $FolderPath,
	    [Parameter(Mandatory=$true)]
	    $Collections,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Device","User")]
	    $CollectionType
	)

    If ($Collections.Name -notcontains $CollectionName)
    {
        LogIt -message ("Create Collection " + $CollectionName) -component "Create-Collection()" -type "Verbose" -LogFile $LogFile
        
        $OBJ_RefreshSchedule = New-CMSchedule –RecurInterval Days –RecurCount 1

        If ($CollectionType -eq 'Device')
        {
            $ReturnCollection = New-CMDeviceCollection -LimitingCollectionId UB100024 -Name $CollectionName -RefreshType Periodic -RefreshSchedule $OBJ_RefreshSchedule
        }
        ElseIf ($CollectionType -eq 'User')
        {
            $ReturnCollection = New-CMUserCollection -LimitingCollectionId SMS00004 -Name $CollectionName -RefreshType Periodic -RefreshSchedule $OBJ_RefreshSchedule
        }
        Else
        {
            LogIt -message ("Collection type unknown.") -component "Create-Collection()" -type "Error" -LogFile $LogFile
            Return
        }

        Move-CMObject -FolderPath $FolderPath -InputObject $ReturnCollection
    }
    Else
    {
        LogIt -message ("Collection " + $CollectionName + " already exists.") -component "Create-Collection()" -type "Verbose" -LogFile $LogFile
        $ReturnCollection = Get-CMDeviceCollection -Name $CollectionName
        $Ignore = Move-CMObject -FolderPath $FolderPath -InputObject $ReturnCollection
    }

    Return $ReturnCollection
}

function Deploy-ApplicationtoSxS
{
	<#
	    .DESCRIPTION
            Creates a set of collections for Side-by-Side (Sxs) deployments. This consists of two collections, one that will be a reporting only collection and one that will be a deployment collection.
        .PARAMETER App
            Application object
        .PARAMETERCollections
            Object for all (device) collections, so we can check if the collection exists or not
        .PARAMETERDeployments
            Object for all deployments, so we can check if it's already deployed or not
        .PARAMETERCMSite
            CM site code is required because collection paths require the site code at the start (unlike all other path objects...)
        .OUTPUTS
            Nothing
	    .EXAMPLE
           Deploy-ApplicationtoSxS $App $Collections $Deployments $CMSite
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $App,
	    [Parameter(Mandatory=$true)]
	    $Collections,
	    [Parameter(Mandatory=$true)]
	    $Deployments,
	    [Parameter(Mandatory=$true)]
        $CMSite
	)

    $SxS_InstalledName = "[SxS Installed] " + $App.LocalizedDisplayName
    $SxS_Name = "[SxS Deployment] " + $App.LocalizedDisplayName
    $SxS_CollectionLocation = $CMSite + ":\DeviceCollection\Operating System Deployment\SxS"

    $SxSInstalledCollection = Create-Collection $SxS_InstalledName $SxS_CollectionLocation $Collections 'Device'

    Add-CollectionVariable $App $SxSInstalledCollection
    Create-DeviceCollectionQuery $App $SxSInstalledCollection

    $SxSDeploymentCollection = Create-Collection $SxS_Name $SxS_CollectionLocation $Collections 'Device'
    Deploy-ApplicationtoCollection $App $SxS_Name 'Install' 'Required' $Deployments

    Return
}


function Add-CollectionVariable
{
	<#
	    .DESCRIPTION
            Creates a set of collection variables for Side-by-Side (Sxs) deployments.
            This consists of four variables, three are 'debugging' level variables
            (to allow us to tie this collection to a unique application),
            and the SxS_ variable is the one used for actual variable based deployments.
        .PARAMETER App
            Application object
        .PARAMETER Collection
            Collection object (should contain just one collection)
        .OUTPUTS
            Nothing
	    .EXAMPLE
           Deploy-ApplicationtoSxS $App $Collection
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $App,
	    [Parameter(Mandatory=$true)]
	    $Collection
	)

    $VariableApplicationName = "ApplicationName"
    $VariableApplicationID = "ApplicationID"
    $VariableApplicationUniqueID = "ApplicationUniqueID"
    $VariableApplicationOSD = "SxS_" + $App.CI_ID

    $VariableApplicationOSD_Exists = Get-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationOSD
    $VariableApplicationName_Exists = Get-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationName
    $VariableApplicationID_Exists = Get-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationID
    $VariableApplicationUniqueID_Exists = Get-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationUniqueID

    $temp = $App.CI_UniqueID.split("/") | select -skip 1
    $ApplicationGUID = $temp.split(" ") | select -First 1

    If (-not $VariableApplicationOSD_Exists)
    {
        LogIt -message ("Variable for OSD does not exist.") -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile

        $Return = New-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationOSD -Value $App.LocalizedDisplayName
    }
    else
    {
        LogIt -message ("Variable for OSD exists.  Setting to current value.") -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile
        $Return = Set-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationOSD -NewVariableValue $App.LocalizedDisplayName
    }

    If (-not $VariableApplicationName_Exists)
    {
        LogIt -message ("Variable for Application name does not exist.") -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile

        $Return = New-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationName -Value $App.LocalizedDisplayName
    }
    else
    {
        LogIt -message ("Variable for Application name exists.  Setting to current value.") -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile
        $Return = Set-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationName -NewVariableValue $App.LocalizedDisplayName
    }


    $temp = $App.CI_UniqueID.split("/") | select -skip 1
    $ApplicationGUID = $temp.split(" ") | select -First 1

    If (-not $VariableApplicationUniqueID_Exists)
    {
        LogIt -message ("Variable for Application Unique ID does not exist.") -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile
        $Return = New-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationUniqueID -Value $ApplicationGUID
    }
    else
    {
        LogIt -message ("Variable for Application Unique ID exists.  Setting to current value.") -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile
        $Return = Set-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationUniqueID -NewVariableValue $ApplicationGUID
    }

    If (-not $VariableApplicationID_Exists)
    {
        LogIt -message ("Variable for Application ID does not exist.") -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile
        $Return = New-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationID -Value $App.CI_ID
    }
    else
    {
        LogIt -message ("Variable for Application ID exists.  Setting to current value.") -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile
        $Return = Set-CMDeviceCollectionVariable -Collection $Collection -VariableName $VariableApplicationID -NewVariableValue $App.CI_ID
    }

    Return
}

function Create-DeviceCollectionQuery
{
	<#
	    .DESCRIPTION
            Creates a set of collection queries for Side-by-Side (Sxs) deployments.
            This consists of (up to) three queries, two for the Product Code found in the
            deployment type window (same field location in the GUI, two locations in the AppXML)
            and one for the Product Code found in the detection method.
        .PARAMETER App
            Application object
        .PARAMETER Collection
            Collection object (should contain just one collection)
        .OUTPUTS
            Nothing
	    .EXAMPLE
           Create-DeviceCollectionQuery $App $Collection
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $App,
	    [Parameter(Mandatory=$true)]
	    $Collection
	)

    $DeploymentTypes = Get-CMDeploymentType -ApplicationName $App.LocalizedDisplayName

    foreach ($DeploymentType in $DeploymentTypes)
    {
        $temp = $DeploymentType.CI_UniqueID.split("/") | select -skip 1
        $DeploymentTypeID = $temp.split(" ") | select -First 1

        $XML = ([xml]$DeploymentType.SDMPackageXML).AppMgmtDigest.DeploymentType | ? { $_.LogicalName -eq $DeploymentTypeID }

		$InstallTechnology = $XML.Technology
		$ProductCode = $XML.Installer.CustomData.ProductCode
        $SourceUpdateProductCode = $XML.Installer.CustomData.SourceUpdateProductCode
    	$DetectionMethodProductCode = $XML.Installer.CustomData.EnhancedDetectionMethod.Settings.MSI.ProductCode

        LogIt -message ("Install Technology: " + $InstallTechnology) -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
        LogIt -message ("Product Code: " + $ProductCode) -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
        LogIt -message ("Source Update Product Code: " + $SourceUpdateProductCode) -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
        LogIt -message ("Detection Method Product Code: " + $DetectionMethodProductCode) -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile

        $RuleName_ProductCode = 'ProductCode_' + $App.CI_ID + '_' + $DeploymentType.LocalizedDisplayName
        $RuleName_SourceUpdateProductCode = 'SourceUpdate_' + $App.CI_ID + '_' + $DeploymentType.LocalizedDisplayName
        $RuleName_DetectionMethodProductCode = 'DetectionCode_' + $App.CI_ID + '_' + $DeploymentType.LocalizedDisplayName
			
		$Query_ProductCode = Get-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -RuleName $RuleName_ProductCode
        $Query_SourceUpdateProductCode = Get-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -RuleName $RuleName_SourceUpdateProductCode
        $Query_DetectionMethodProductCode = Get-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -RuleName $RuleName_DetectionMethodProductCode

        LogIt -message ("Processing Product Code") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile

	    If ($Query_ProductCode)
	    {
	        LogIt -message ("Query (" + $RuleName_ProductCode + ") already exists.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
		}
        ElseIf (-not $ProductCode)
        {
            LogIt -message ("Product Code does not exist for this Deployment Type.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
        }
	    Else
	    {
	        LogIt -message ("Query (" + $RuleName_ProductCode + ") missing.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile

	        $CollQuery = "select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_INSTALLED_SOFTWARE on SMS_G_System_INSTALLED_SOFTWARE.ResourceID = SMS_R_System.ResourceId where UPPER(SMS_G_System_INSTALLED_SOFTWARE.SoftwareCode) = `"" + $ProductCode + "`""

	        Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -RuleName $RuleName_ProductCode -QueryExpression $CollQuery
	    }

        LogIt -message ("Processing Source Update Product Code") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
        

	    If ($Query_SourceUpdateProductCode)
	    {
	        LogIt -message ("Query (" + $RuleName_SourceUpdateProductCode + ") already exists.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
		}
        ElseIf (-not $SourceUpdateProductCode)
        {
            LogIt -message ("Source Update Product Code does not exist for this Deployment Type.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
        }
	    Else
	    {
	        LogIt -message ("Query (" + $RuleName_SourceUpdateProductCode + ") missing.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile

	        $CollQuery = "select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_INSTALLED_SOFTWARE on SMS_G_System_INSTALLED_SOFTWARE.ResourceID = SMS_R_System.ResourceId where UPPER(SMS_G_System_INSTALLED_SOFTWARE.SoftwareCode) = `"" + $SourceUpdateProductCode + "`""

	        Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -RuleName $RuleName_SourceUpdateProductCode -QueryExpression $CollQuery
	    }


        LogIt -message ("Processing Detection Method Product Code") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile

	    If ($Query_DetectionMethodProductCode)
	    {
	        LogIt -message ("Query (" + $RuleName_DetectionMethodProductCode + ") already exists.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
		}
        ElseIf (-not $DetectionMethodProductCode)
        {
            LogIt -message ("MSI Detection Method Product Code does not exist for this Deployment Type.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile
        }
	    Else
	    {
	        LogIt -message ("Query (" + $RuleName_DetectionMethodProductCode + ") missing.") -component "Create-DeviceCollectionQuery()" -type "Verbose" -LogFile $LogFile

	        $CollQuery = "select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_INSTALLED_SOFTWARE on SMS_G_System_INSTALLED_SOFTWARE.ResourceID = SMS_R_System.ResourceId where UPPER(SMS_G_System_INSTALLED_SOFTWARE.SoftwareCode) = `"" + $DetectionMethodProductCode + "`""

	        Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -RuleName $RuleName_DetectionMethodProductCode -QueryExpression $CollQuery
	    }

    }

    Return
}

function Deploy-ApptoDistributionPointGroup
{
	<#
	    .DESCRIPTION 
            Deploys an app to Distribution Point Groups
        .PARAMETER App
            Application object
        .PARAMETER DistributionPointGroups
            An Array of Distribution Point Group names
        .OUTPUTS
            Nothing
	    .EXAMPLE
            Deploy-ApptoDistributionPointGroup $App @("Datacenters - All - Internal","Regional","DMZ - Internet-Facing","Stores - All")
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $App,
	    [Parameter(Mandatory=$true)]
	    $DistributionPointGroups
	)


    ForEach ($DistributionPointGroup in $DistributionPointGroups)
    {
        LogIt -message ("Distributing " + $App.LocalizedDisplayName + " to " + $DistributionPointGroup) -component "Deploy-ApptoDistributionPointGroup()" -type "Verbose" -LogFile $LogFile

        #We have to wrap this in a Try/Catch because if it's already deployed to the group, it will throw an error, which ErrorAction SilentlyContinue does not actually silently continue.
        #This means the try will ALWAYS fail, unless everything is completely valid *AND* it's the first time we've every deployed this to the DP group.
        Try
        {
            Start-CMContentDistribution -Application $App -DistributionPointGroupName $DistributionPointGroup -ErrorAction SilentlyContinue
        }
        Catch
        {
            #Do nothing
        }
    }

    Return

}

function Remove-ApptoDistributionPointGroup
{
	<#
	    .DESCRIPTION 
            Removes an app from Distribution Point Groups
        .PARAMETER App
            Application object
        .PARAMETER DistributionPointGroups
            An Array of Distribution Point Group names
        .OUTPUTS
            Nothing
	    .EXAMPLE
            Remove-ApptoDistributionPointGroup $App @("Datacenters - All - Internal","Regional","DMZ - Internet-Facing","Stores - All")
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    $App,
	    [Parameter(Mandatory=$true)]
	    $DistributionPointGroups
	)


    ForEach ($DistributionPointGroup in $DistributionPointGroups)
    {
        LogIt -message ("Removing " + $App.LocalizedDisplayName + " from " + $DistributionPointGroup) -component "AddCollectionVariable()" -type "Verbose" -LogFile $LogFile

        #We have to wrap this in a Try/Catch because if it's already deployed to the group, it will throw an error, which ErrorAction SilentlyContinue does not actually silently continue.
        #This means the try will ALWAYS fail, unless everything is completely valid *AND* it's the first time we've every deployed this to the DP group.
        Try
        {
            Remove-CMContentDistribution -Application $App -DistributionPointGroupName $DistributionPointGroup -Force -ErrorAction SilentlyContinue
        }
        Catch
        {
            #Do nothing
        }
    }

    Return

}
