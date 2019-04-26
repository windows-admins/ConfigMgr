<#
    .SYNOPSIS 
      Automatically creates applications in System Center 2012 Configuration Manager.  Currently only works for MSI applications that can use the built-in System Center 2012 Configuration Manager MSI autodetection process.  This script only applies to applications, it does not apply to packages.
    .DESCRIPTION
      This script accepts user input, then proceeds to automatically create an application, collections, and deployments based on the input given.  If required values are not entered, the script will prompt for input.  Most default values can be overwritten by passing additional parameters.
	  Required Input:
	  -CMApplication_Name
	  -CM_Application_Publisher
	  -CMApplication_SoftwareVersion
	  -CMDeploymentType_ContentLocation
	  -CMDeploymentType_InstallationFile
    .EXAMPLE
     .\Create_Application.ps1 -CMApplication_Name "Visual C++ 2005 SP1 Redistributable Package (x64)" -CMApplication_Publisher "Microsoft" -CMApplication_SoftwareVersion "3.1337.80085" -CMDeploymentType_ContentLocation "\\pdx-sccm-app01\source$\Apps\Microsoft\Microsoft Visual C++ 2005 SP1 Redistributable Package (x64)" -CMDeploymentType_InstallationFile "vcredist.msi"
	 This command uses the minimal amount of required input to create an application named "Microsoft_Visual C++ 2005 SP1 Redistributable Package (x64) 3.1337.80085" and the matching collections and deployments.
    .EXAMPLE
     .\Create_Application.ps1
     This command will run the script, which will prompt for input.
#>

#region --------Parameters and Variables------------
Param(
	#-------------------------------
	#Variables for Global System Variables

	#SCCM Site Code
	#Example: HDC:
	[string]$CMSite = "HDC:",
	#Prefix used for device objects
	#Example: DEV_D_
	[string]$Prefix_Device = "DEV_D_",
	#Prefix used for user objects
	#Example: DEV_U_
	[string]$Prefix_User = "DEV_U_",

	
	#-------------------------------
	#Variables for Global System Variables
	#Logging settings
	
	#Enable Verbose logging
	#Example: $true
	[bool]$Global:Verbose = $true,
	#Where to save the log file
	#Example: "a.log"
	[string]$Global:LogFile = "a.log",
	#Maximum size of the log file before we create a new one.
	#Example: 10240
	[int]$Global:MaxLogSizeInKB = 10240,
	
	#-------------------------------
	#Variables for New-CMApplication
	
	#Specifies a name for the application.
	#Example: Office 2010
	#Example: Flash
	[Parameter(Mandatory=$True)]
	[string]$CMApplication_Name,
	#Specifies the name of a software publisher in Configuration Manager
	#Example: Microsoft
	#Example: Adobe
	[Parameter(Mandatory=$True)]
	[string]$CMApplication_Publisher,
	#Specifies a description for the application. The description appears in the administrator console.
	[string]$CMApplication_Description,
	#Specifies a software version for the application.
	#Example: 3.1337.80085
	[Parameter(Mandatory=$True)]
	[string]$CMApplication_SoftwareVersion,
	#Specifies whether a task sequence action can install the application.
	#Example: $true
	[bool]$CMApplication_AutoInstall = $true,
	#Featured application in the application catalog
	#Example: $true
	[bool]$CMApplication_IsFeatured,
	
	#-------------------------------
	#Variables for Add-CMDeploymentType
	
	#Specifies the path of the content. The site system server requires permission to read the content files.
	#Example: \\pdx-sccm-app01\source$\Apps\Microsoft\Microsoft Visual C++ 2005 SP1 Redistributable Package (x64)\
	[Parameter(Mandatory=$True)]
	[ValidateScript({Test-Path $_ -PathType 'Container'})] 
	[string]$CMDeploymentType_ContentLocation,
	#Specifies the installation package.
	#Example: vcredist.msi
	[Parameter(Mandatory=$True)]
	[string]$CMDeploymentType_InstallationFile,
	#Indicates whether the deployment type requires file signature verification.
	#Example: $true
	[bool]$CMDeploymentType_ForceForUnknownPublisher = $true,
	#Indicates whether clients can use a fallback location provided by a management point. A fallback location point provides an alternate location for source content when the content for the deployment type is not available on any preferred distribution points.
	#Example: $true
	[bool]$CMDeploymentType_AllowClientsToUseFallbackSourceLocationForContent,
	#Indicates whether clients can share content with other clients on the same subnet.
	#Example: $true
	[bool]$CMDeploymentType_AllowClientsToShareContentOnSameSubnet = $true,
	#Specifies the installation behavior of the deployment type. Valid values are: 
	#-- InstallForSystem
	#-- InstallForSystemIfResourceIsDeviceOtherwiseInstallForUser
	#-- InstallForUser
	#Example: InstallForSystem
	[ValidateSet("InstallForSystem","InstallForSystemIfResourceIsDeviceOtherwiseInstallForUser","InstallForUser")] 
	[string]$CMDeploymentType_InstallationBehaviorType = "InstallForSystem",
	#Specifies the logon requirement for the deployment type. Valid values are: 
	#-- OnlyWhenNoUserLoggedOn
	#-- OnlyWhenUserLoggedOn
	#-- WhereOrNotUserLoggedOn
	#Example: WhereOrNotUserLoggedOn
	[ValidateSet("OnlyWhenNoUserLoggedOn","OnlyWhenUserLoggedOn","WhereOrNotUserLoggedOn")] 
	[string]$CMDeploymentType_LogonRequirementType = "WhereOrNotUserLoggedOn",
	#Specifies the installation behavior of the deployment type on a slow network. Valid values are: 
	#-- DoNothing
	#-- Download
	#-- DownloadContentForStreaming
	#Example: DoNothing
	[ValidateSet("DoNothing","Download","DownloadContentForStreaming")] 
	[string]$CMDeploymentType_OnSlowNetworkMode = "DoNothing",
	
	#-------------------------------
	#Variables for Start-CMContentDistribution
	
	#Specifies the name of a distribution point group.
	#Example: _UTaSC DPs
	#Example: All UB Distribution Points
	[string]$CMContentDistribution_DistributionPointGroupName = "_UTaSC DPs",
	
	#-------------------------------
	#Variables for Collection
	
	#Path to the folder
	#Example: Development\Test
	[string]$Collection_Path = "Development\Test",
	
	#-------------------------------
	#Machine to add to collection
	
	#Workstation Name
	#Example: EngineerTestMachine1
	[string]$WorkstationName
	
	#
	)
	
#Variables we use internally
[string]$CMApplication_AppName = $CMApplication_Publisher + "_" + $CMApplication_Name + " " + $CMApplication_SoftwareVersion
[string]$CMDeploymentType_InstallationFileLocation = $CMDeploymentType_ContentLocation + "\" + $CMDeploymentType_InstallationFile

#endregion ---------------------------------------


#region --------Setup and Configuration------------
#Import Modules
Import-Module $PSScriptRoot\Module_LogIt
$LogFile = $PSScriptRoot + "\" + $LogFile

LogIt -message (" ") -component "Other()" -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component "Other()" -type "Info" -LogFile $LogFile
LogIt -message ("Initializing application deployment.") -component "Other()" -type "Info" -LogFile $LogFile
LogIt -message ("Logging messages to: $LogFile") -component "Other()" -type "Info" -LogFile $LogFile

#import the ConfigMgr Module
LogIt -message ("Importing: $(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1") -component "Other()" -type "Info" -LogFile $LogFile
Import-Module -Name "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"

#set the location to the CMSite
LogIt -message ("Connecting to: " + $CMSite) -component "Other()" -type "Info" -LogFile $LogFile
Set-Location -Path $CMSite

#endregion ---------------------------------------

#region --------[MAIN]Main Body of Code------------
	#Validate what exists already.
	$OBJ_Application_Temp = Get-CMApplication -Name $CMApplication_AppName
	$OBJ_DeploymentType_Temp = Get-CMDeploymentType -ApplicationName $CMApplication_AppName
	$OBJ_DeviceCollection_Temp = Get-CMDeviceCollection -Name ($Prefix_Device + $CMApplication_AppName)
	$OBJ_UserCollection_Temp = Get-CMUserCollection -Name ($Prefix_User + $CMApplication_AppName)
	
	if (($OBJ_Application_Temp) -or ($OBJ_DeploymentType_Temp) -or ($OBJ_DeviceCollection_Temp) -or ($OBJ_UserCollection_Temp))
	{
		LogIt -message ("The following objects already exist.") -component "Validation()" -type "Error" -LogFile $LogFile
		
		if ($OBJ_Application_Temp)
		{
			LogIt -message ("Application: Yes") -component "Validation()" -type "Warning" -LogFile $LogFile
		}
		else
		{
			LogIt -message ("Application: No") -component "Validation()" -type "Warning" -LogFile $LogFile
		}
		
		if ($OBJ_DeploymentType_Temp)
		{
			LogIt -message ("Deployment Type: Yes") -component "Validation()" -type "Warning" -LogFile $LogFile
		}
		else
		{
			LogIt -message ("Deployment Type: No") -component "Validation()" -type "Warning" -LogFile $LogFile
		}
		
		if ($OBJ_DeviceCollection_Temp)
		{
			LogIt -message ("Device Collection: Yes") -component "Validation()" -type "Warning" -LogFile $LogFile
		}
		else
		{
			LogIt -message ("Device Collection: No") -component "Validation()" -type "Warning" -LogFile $LogFile
		}
		
		if ($OBJ_UserCollection_Temp)
		{
			LogIt -message ("User Collection: Yes") -component "Validation()" -type "Warning" -LogFile $LogFile
		}
		else
		{
			LogIt -message ("User Collection: No") -component "Validation()" -type "Warning" -LogFile $LogFile
		}
	
		LogIt -message ("(Recommended action is to clean up existing components manually.)") -component "Validation()" -type "Info" -LogFile $LogFile
		
		$choice = ""
		while ($choice -notmatch "[y|n]")
		{
			$choice = read-host "Do you want to continue? (Y/N)"
		}

		if ($choice -eq "y")
		{
			LogIt -message ("Executing script. Validating of results recommended.") -component "Validation()" -type "Info" -LogFile $LogFile
		}
		else
		{
			LogIt -message ("Aborting script execution.") -component "Validation()" -type "Info" -LogFile $LogFile
			Exit
		}
	}



	#region --------[SUB] Create a new application and deployment type------------
	#create a new Application
    try
    {
        LogIt -message ("Creating Application: " + $CMApplication_AppName) -component "CreateApplication()" -type "Info" -LogFile $LogFile
		$PARAM_CMApplication = @{Publisher = $CMApplication_Publisher;
								Name = $CMApplication_AppName;
								Description = $CMApplication_Description;
								LocalizedApplicationName = $CMApplication_AppName;
								LocalizedApplicationDescription = $CMApplication_Description;
								SoftwareVersion = $CMApplication_SoftwareVersion;
								AutoInstall = $CMApplication_AutoInstall;
								IsFeatured = $CMApplication_IsFeatured}

		$OBJ_CMApplication = New-CMApplication @PARAM_CMApplication
		
		#Set new properties on the Application Object Created.
		Set-CMApplication -InputObject $OBJ_CMApplication -SendToProtectedDistributionPoint $true 
    }
    catch
    {
        LogIt -message ("Could not create application.") -component "CreateApplication()" -type "Error" -LogFile $LogFile
    }

	#Add the Deployment type automatically from the MSI 
    try
    {
		LogIt -message ("Creating deployment type for application.") -component "CreateApplication()" -type "Info" -LogFile $LogFile

		#These break the params for some reason
		#Add-CMDeploymentType : Parameter set cannot be resolved using the specified named parameters.
		#AllowClientsToShareContentOnSameSubnet = $CMDeploymentType_AllowClientsToShareContentOnSameSubnet;
		#LogonRequirementType = $CMDeploymentType_LogonRequirementType;
		$PARAM_CMDeploymentType = @{ApplicationName = $CMApplication_AppName;
									InstallationFileLocation = $CMDeploymentType_InstallationFileLocation;
									ForceForUnknownPublisher = $CMDeploymentType_ForceForUnknownPublisher;
									InstallationBehaviorType = $CMDeploymentType_InstallationBehaviorType;
									AllowClientsToUseFallbackSourceLocationForContent = $CMDeploymentType_AllowClientsToUseFallbackSourceLocationForContent;
									OnSlowNetworkMode = $CMDeploymentType_OnSlowNetworkMode}

		Add-CMDeploymentType -MsiInstaller -AutoIdentifyFromInstallationFile @PARAM_CMDeploymentType 
    }
    catch
    {
        LogIt -message ("Could not create deployment type.") -component "CreateApplication()" -type "Error" -LogFile $LogFile
    }

	#endregion ---------------------------------------

	#region --------[SUB] Distribute content to the DP group------------
	#Distribute the Content to the DP Group
    try
	{
		LogIt -message ("Distributing content to: " + $CMContentDistribution_DistributionPointGroupName) -component "DistributeContent()()" -type "Info" -LogFile $LogFile
		#For some reason (bug), we can't use the object returned by New-CMApplication (throws an error). So let's get the object again, and use that.
		#Start-CMContentDistribution -Application $OBJ_CMApplication -DistributionPointGroupName $CMContentDistribution_DistributionPointGroupName -ErrorAction Continue -Verbose -Debug
		$OBJ_Temp = Get-CMApplication -Name $OBJ_CMApplication.LocalizedDisplayName
		
		$PARAM_CMContentDistribution = @{Application = $OBJ_Temp;
										DistributionPointGroupName = $CMContentDistribution_DistributionPointGroupName}
		
		Start-CMContentDistribution @PARAM_CMContentDistribution
	}
    catch
    {
        LogIt -message ("Could not distribute content to the DP group.") -component "DistributeContent()" -type "Error" -LogFile $LogFile
    }
	#endregion ---------------------------------------

	#region --------[SUB] Create Collection and Deployment------------
	
    try
	{
		#Create a schedule
		LogIt -message ("Creating schedule for collections.") -component "CreateCollection()" -type "Verbose" -LogFile $LogFile
		
		$PARAM_RefreshSchedule = @{RecurInterval = "Days";
									RecurCount = "1"}
		
		$OBJ_RefreshSchedule = New-CMSchedule @PARAM_RefreshSchedule
	}
    catch
    {
        LogIt -message ("Could not create schedule.") -component "CreateCollection()" -type "Error" -LogFile $LogFile
    }
	
    try
	{
		LogIt -message ("Creating device collection: " + $Prefix_Device + $CMApplication_AppName) -component "CreateCollection()" -type "Info" -LogFile $LogFile

		$PARAM_DeviceCollection = @{LimitingCollectionId = "SMS00001";
								Name = ($Prefix_Device + $CMApplication_AppName);
								Comment = "Auto generated";
								RefreshType = "Both";
								RefreshSchedule = $OBJ_RefreshSchedule}
		
	    $OBJ_DeviceCollection = New-CMDeviceCollection @PARAM_DeviceCollection
	}
    catch
    {
        LogIt -message ("Could not create device collection.") -component "CreateCollection()" -type "Error" -LogFile $LogFile
    }
	
	#Move collection to correct spot
    try
    {
        LogIt -message ("Moving collection to: " + $CMSite + "\DeviceCollection\" + $Collection_Path) -component "MoveObject()" -type "Info" -LogFile $LogFile
		
		$PARAM_CMObject = @{FolderPath = ($CMSite + "\DeviceCollection\" + $Collection_Path);
						InputObject = $OBJ_DeviceCollection}
		
        Move-CMObject @PARAM_CMObject
    }
    catch
    {
        LogIt -message ("Could not move object.  Have you created the folder?") -component "MoveObject()" -type "Warning" -LogFile $LogFile
        LogIt -message ("(This can be ignored if the collection already existed in the location we just attempted to move it to.)") -component "MoveObject()" -type "Warning" -LogFile $LogFile
    }


	
	#Add the Direct Membership Rule to add a Resource as a member to the Collection
	Add-CMDeviceCollectionDirectMembershipRule -CollectionName ($Prefix_Device + $CMApplication_AppName)  -Resource (Get-CMDevice -Name $WorkstationName)
	
    try
	{
		LogIt -message ("Creating user collection: " + $Prefix_User + $CMApplication_AppName) -component "CreateCollection()" -type "Info" -LogFile $LogFile
		
		$PARAM_UserCollection = @{LimitingCollectionId = "SMS00001";
								Name = ($Prefix_User + $CMApplication_AppName);
								Comment = "Auto generated";
								RefreshType = "Both";
								RefreshSchedule = $OBJ_RefreshSchedule}
		
	    $OBJ_UserCollection = New-CMUserCollection @PARAM_UserCollection
	}
    catch
    {
        LogIt -message ("Could not create user collection.") -component "CreateCollection()" -type "Error" -LogFile $LogFile
    }

	#Move collection to correct spot
    try
    {
        LogIt -message ("Moving collection to: " + $CMSite + "\UserCollection\" + $Collection_Path) -component "MoveObject()" -type "Info" -LogFile $LogFile
		
		$PARAM_CMObject = @{FolderPath = ($CMSite + "\UserCollection\" + $Collection_Path);
						InputObject = $OBJ_UserCollection}
		
        Move-CMObject @PARAM_CMObject
    }
    catch
    {
        LogIt -message ("Could not move object.  Have you created the folder?") -component "MoveObject()" -type "Warning" -LogFile $LogFile
        LogIt -message ("(This can be ignored if the collection already existed in the location we just attempted to move it to.)") -component "MoveObject()" -type "Warning" -LogFile $LogFile
    }

	#start the Deployment
    try
    {
		LogIt -message ("Creating deployment for device collection.") -component "CreateDeployment()" -type "Info" -LogFile $LogFile
		
		$PARAM_CMApplicationDeployment = @{CollectionName = ($Prefix_Device + $CMApplication_AppName);
											Name = $CMApplication_AppName;
											AppRequiresApproval = $false;
											DeployAction = "Install";
											DeployPurpose = "Available";
											EnableMomAlert = $false;
											RebootOutsideServiceWindow = $false;
											UseMeteredNetwork = $false;
											UserNotification = "DisplaySoftwareCenterOnly";
											AvaliableDate = (get-date);
											AvaliableTime = (get-date);
											TimeBaseOn = "LocalTime"}
		
		Start-CMApplicationDeployment @PARAM_CMApplicationDeployment
    }
	catch
    {
        LogIt -message ("Could not create deployment.") -component "MoveObject()" -type "Error" -LogFile $LogFile
    }
	
    try
    {
		LogIt -message ("Creating deployment for user collection.") -component "CreateDeployment()" -type "Info" -LogFile $LogFile
		
		$PARAM_CMApplicationDeployment = @{CollectionName = ($Prefix_User + $CMApplication_AppName);
											Name = $CMApplication_AppName;
											AppRequiresApproval = $false;
											DeployAction = "Install";
											DeployPurpose = "Available";
											EnableMomAlert = $false;
											RebootOutsideServiceWindow = $false;
											UseMeteredNetwork = $false;
											UserNotification = "DisplaySoftwareCenterOnly";
											AvaliableDate = (get-date);
											AvaliableTime = (get-date);
											TimeBaseOn = "LocalTime"}
		
		Start-CMApplicationDeployment @PARAM_CMApplicationDeployment
    }
	catch
    {
		LogIt -message ("Could not create deployment.") -component "MoveObject()" -type "Error" -LogFile $LogFile
    }

	#refresh the Machine Policy on the Members of the Collection
	LogIt -message ("Refreshing machine policies for device collection.") -component "Other()" -type "Info" -LogFile $LogFile
	
	$PARAM_CMClientNotification = @{DeviceCollectionName = ($Prefix_Device + $CMApplication_AppName);
									NotificationType = "RequestMachinePolicyNow"}
	
	Invoke-CMClientNotification @PARAM_CMClientNotification 

	#Run the Deployment Summarization
	LogIt -message ("Running Deployment Summarization.") -component "Other()" -type "Info" -LogFile $LogFile
	
	$PARAM_CMDeploymentSummarization = @{CollectionName = ($Prefix_Device + $CMApplication_AppName)}
	
	Invoke-CMDeploymentSummarization @PARAM_CMDeploymentSummarization
	#endregion ---------------------------------------

LogIt -message ("Application creation and deployment complete.") -component "Other()" -type "Info" -LogFile $LogFile
#endregion ---------------------------------------
