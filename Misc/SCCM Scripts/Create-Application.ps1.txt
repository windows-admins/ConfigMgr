<#
    .DESCRIPTION
        Creates Application and Deployment Types.
        This script is run against an XML file, and then can deploy applications to Development, Production, or Retire them.
    .PARAMETER $XMLDocument
        Path to the XML document to read, where the applications that need to be modified (created, moved into Production, or Retired) are documented.
    .PARAMETER $Action
        Action to be taken against the XML Document.  Provided actions are Development, Production, or Retired.
    .PARAMETER CMSite
        CM site code
    .PARAMETER CMServer
        CM site server
    .PARAMETER VerboseLogging
        If VerboseLogging is set to be $true, then detailed logging will be written
    .INPUTS
        None. You cannot pipe objects in.
    .OUTPUTS
        None. Does not generate any output.
    .EXAMPLE
        .\CreateApplication.ps1 -XMLDocument "c:\temp\Applications.xml" -Action "Development"
        Creates the application and collections for the development environment.
    .EXAMPLE
        .\CreateApplication.ps1 -XMLDocument "c:\temp\Applications.xml" -Action "Production"
        Moves the applications from development to production.
    .EXAMPLE
        .\CreateApplication.ps1 -XMLDocument "c:\temp\Applications.xml" -Action "Retired"
        Moves the Applications to the Retired folder.
#>

Param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType 'Leaf'})] 
    [string]$XMLDocument,
    [Parameter(Mandatory=$true)]
    [ValidateSet("Development","Production","Retired")] 
    $Action,
    [string]$CMSite = "ABC",
    [string]$CMServer = "server.domain.com",
    [bool]$VerboseLogging = $false
)

#________________________________________________________

#Logging settings
[bool]$Global:Verbose = [System.Convert]::ToBoolean($VerboseLogging)
$Global:LogFile = Join-Path ($PSScriptRoot) 'Create-Application.log' 
$Global:MaxLogSizeInKB = 10240
$Global:ScriptName = 'Create-Application' 


#________________________________________________________

#region --------Import XML File--------------------
$XMLPath = Resolve-Path -Path $XMLDocument

[xml]$XML = Get-Content -Path $XMLPath.Path
#endregion ---------------------------------------

#region --------Setup and Configuration------------
#Import Modules
Remove-Module $PSScriptRoot\Module_LogIt -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot\Module_LogIt -WarningAction SilentlyContinue

LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component "Main()" -type "Info" -LogFile $LogFile

#import the ConfigMgr Module
LogIt -message ("Importing ConfigurationManager.psd1") -component "Main()" -type "Info" -LogFile $LogFile
Import-Module -Name "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"

#set the location to the CMSite
LogIt -message ("Connecting to: " + $CMSite) -component "Main()" -type "Info" -LogFile $LogFile

$CMSiteColon = $CMSite + ":"
Set-Location -Path $CMSiteColon

#Import the function libary.  Remove it first, because in the PowerShell IDE, it caches it.
LogIt -message ("Importing Function module") -component "Main()" -type "Info" -LogFile $LogFile
Remove-Module Functions -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot\Functions -WarningAction SilentlyContinue

#endregion ---------------------------------------

ForEach ($Application in $XML.Applications.Application)
{
    LogIt -message ("Processing Application: " + $Application.Name) -component "CreateApplication()" -type "Info" -LogFile $LogFile

    $OBJ_CMApplication = Get-CMApplication -Name $Application.Name

    If ($OBJ_CMApplication)
    {
        LogIt -message ("Application with this name already exists: " + $OBJ_CMApplication.LocalizedDisplayName) -component "CreateApplication()" -type "Warning" -LogFile $LogFile
    }
    Else
    {

        try
        {
            LogIt -message ("Creating Application: " + $Application.Name) -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
		    $PARAM_CMApplication = @{Publisher = $Application.Publisher;
								    Name = $Application.Name;
								    LocalizedApplicationName = $Application.Name;
								    SoftwareVersion = $Application.Version;
								    AutoInstall = $true;
								    IsFeatured = $false}

		    $OBJ_CMApplication = New-CMApplication @PARAM_CMApplication
		
		    #Set new properties on the Application Object Created.
		    #Set-CMApplication -InputObject $OBJ_CMApplication -SendToProtectedDistributionPoint $true 
        }
        catch
        {
            LogIt -message ("Could not create application.") -component "CreateApplication()" -type "Error" -LogFile $LogFile
            LogIt -message ($ErrorMessage) -component "CreateApplication()" -type "Error" -LogFile $LogFile
        }
    }

    ForEach ($DeploymentType in $Application.DeploymentType)
    {
        LogIt -message ("Processing Deployment Type: " + $DeploymentType.Name) -component "CreateApplication()" -type "Verbose" -LogFile $LogFile

	    #Add the Deployment type automatically from the MSI 
        try
        {
		    LogIt -message ("Creating deployment type for application.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile

            If ($DeploymentType.MSIInstallationFileLocation)
            {
                LogIt -message ("Creating MSI deployment type") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile

                If (Test-Path $DeploymentType.MSIInstallationFileLocation -PathType 'Leaf')
                {
		            $PARAM_CMDeploymentType = @{AllowClientsToUseFallbackSourceLocationForContent = $false;
                                                ApplicationName = $OBJ_CMApplication.LocalizedDisplayName;
									            ForceForUnknownPublisher = $true;
									            InstallationFileLocation = $DeploymentType.MSIInstallationFileLocation;
									            InstallationBehaviorType = $DeploymentType.InstallationBehaviorType
                                                OnSlowNetworkMode = 'DoNothing'}

                    $OBJ_DeploymentType = Add-CMDeploymentType -MsiInstaller -AutoIdentifyFromInstallationFile @PARAM_CMDeploymentType
                }
                Else
                {
                    LogIt -message ("MSI does not exist at: " + $DeploymentType.MSIInstallationFileLocation) -component "CreateApplication()" -type "Error" -LogFile $LogFile
                }
            }
            Else
            {
                LogIt -message ("Creating non-MSI deployment type") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile

		        $PARAM_CMDeploymentType = @{AllowClientsToShareContentOnSameSubnet = $true;
                                            ApplicationName = $OBJ_CMApplication.LocalizedDisplayName;
                                            ContentLocation = $DeploymentType.ContentLocation;
                                            DeploymentTypeName = $DeploymentType.Name;
									        InstallationBehaviorType = $DeploymentType.InstallationBehaviorType;
                                            InstallationProgram = $DeploymentType.InstallationProgram;
                                            ScriptContent = $DeploymentType.ScriptContent;
                                            ScriptType = $DeploymentType.ScriptType;
                                            InstallationProgramVisibility = "Hidden";
                                            LogonRequirementType = "WhereOrNotUserLoggedOn";
                                            UninstallProgram = $DeploymentType.UninstallProgram}

                $OBJ_DeploymentType = Add-CMDeploymentType -ScriptInstaller @PARAM_CMDeploymentType 
            }
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName

            If ($ErrorMessage -like "*because one with the same name already exist*")
            {
                $ErrorType = "Warning"
            }
            Else
            {
                $ErrorType = "Error"
            }

            LogIt -message ("Could not create deployment type.") -component "CreateApplication()" -type $ErrorType -LogFile $LogFile
            LogIt -message ($ErrorMessage) -component "CreateApplication()" -type $ErrorType -LogFile $LogFile
        }
    }

    #Set the category

    if ($Application.Licensed -eq "True" -or $Application.Licensed -eq "Yes")
    {
        LogIt -message ("Application is licensed.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile

        if ($OBJ_CMApplication.LocalizedCategoryInstanceNames -notcontains "Licensed")
        {
            LogIt -message ("Adding application category.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
            $Result = Set-CMApplication -InputObject $OBJ_CMApplication -AppCategory "Licensed"
        }
    }

    if ($Application.ManualInstallation -eq "True" -or $Application.ManualInstallation -eq "Yes")
    {
        LogIt -message ("Application is a Manual Installation.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile

        if ($OBJ_CMApplication.LocalizedCategoryInstanceNames -notcontains "Manual Installation")
        {
            LogIt -message ("Adding application category.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
            $Result = Set-CMApplication -InputObject $OBJ_CMApplication -AppCategory "Manual Installation"
        }
    }

    if ($Application.AppV -eq "True" -or $Application.AppV -eq "Yes")
    {
        LogIt -message ("Application is an App-V app.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile

        if ($OBJ_CMApplication.LocalizedCategoryInstanceNames -notcontains "App-V")
        {
            LogIt -message ("Adding application category.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
            $Result = Set-CMApplication -InputObject $OBJ_CMApplication -AppCategory "App-V"
        }
    }

    switch ($Action)
    {
        Development
        {
            LogIt -message ("Moving application to the Development folder.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
            Move-CMObject -FolderPath '\Application\Development' -InputObject $OBJ_CMApplication
        }
        Production
        {
            LogIt -message ("Moving application to the Production folder.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
            Move-CMObject -FolderPath '\Application\Production' -InputObject $OBJ_CMApplication
        }
        Retired
        {
            LogIt -message ("Moving application to the Retired folder.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
            Move-CMObject -FolderPath '\Application\Retired' -InputObject $OBJ_CMApplication
        }
    }

    LogIt -message ("Add application to Application Lifecycle list.") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile

    If ($ApplicationLifeCycleList)
    {
        $ApplicationLifeCycleList = $ApplicationLifeCycleList + "," + $OBJ_CMApplication.LocalizedDisplayName
    }
    Else
    {
        $ApplicationLifeCycleList = $OBJ_CMApplication.LocalizedDisplayName
    }

    LogIt -message ("Current Application Lifecycle list: $ApplicationLifeCycleList") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
}

#Call other script with the script name
LogIt -message ("Executing Application Lifecycle processing.") -component "CreateApplication()" -type "Info" -LogFile $LogFile
LogIt -message ("Execution command line: ") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
LogIt -message ("ApplicationLifecycle.ps1 -ApplicationName $ApplicationLifeCycleList -Turbo $true -CMSite $CMSite -CMServer $CMServer -VerboseLogging $Verbose") -component "CreateApplication()" -type "Verbose" -LogFile $LogFile
& $PSScriptRoot\ApplicationLifecycle.ps1 -ApplicationName $ApplicationLifeCycleList -Turbo $true -CMSite $CMSite -CMServer $CMServer -VerboseLogging $Verbose

Return
