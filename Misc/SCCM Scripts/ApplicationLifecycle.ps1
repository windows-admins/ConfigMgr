<#
    .DESCRIPTION
        Handles Application life cycle management.
        This script is designed to run automatically, without requiring intervention or input.
    .PARAMETER ApplicationName
        Name of application. Can be a single application name, part of a name with a wild card, or a list of applications (comma delimited)
    .PARAMETER CMSite
        CM site code
    .PARAMETER CMServer
        CM site server
    .PARAMETER Turbo
        If Turbo is set to be $true, then it will skip the collection cleanup step
    .PARAMETER Cleanup
        If Cleanup is set to be $true, then it will run the application and cleanup steps (skipping the steps that build the application collection and deployments). If both Cleanup and Turbo are set to be true, it will run the application cleanup but not the collection cleanup steps.
    .PARAMETER VerboseLogging
        If VerboseLogging is set to be $true, then detailed logging will be written
    .INPUTS
        None. You cannot pipe objects.
    .OUTPUTS
        None. Does not generate any output.
    .EXAMPLE
        .\ApplicationLicecycle.ps1 -ApplicationName "Microsoft Office 2013 Professional Pro Plus"
        This command creates collections and deployments for a single application.
    .EXAMPLE
        .\ApplicationLicecycle.ps1 -ApplicationName "*NET Framework 4*"
        This command creates collections and deployments for all applications that have NET Framework 4 in the name.
        Notice the wildcards, and the quotes due to the spaces.
    .EXAMPLE
        .\ApplicationLicecycle.ps1 -ApplicationName "Microsoft Office 2013 Professional Pro Plus,Microsoft Office 2010 Professional Pro Plus"
        This command creates collections and deployments for two specific applications.
    .EXAMPLE
        .\ApplicationLicecycle.ps1 -ApplicationName "Adobe*,Microsoft*"
        This command creates collections and deployments for all Adobe and Microsoft products.
    .EXAMPLE
        .\AutoGenerateApplicationDeployments.ps1
        This command creates collections and deployments for all applications.
        WARNING: This process can take an extremely long time to run.
#>

Param(
[string]$ApplicationName = 'A*,B*,C*,D*,E*,F*,G*,H*,I*,J*,K*,L*,M*,N*,O*,P*,Q*,R*,S*,T*,U*,V*,W*,X*,Y*,Z*,1*,2*,3*,4*,5*,6*,7*,8*,9*,0*',
[string]$CMSite = "ABC",
[string]$CMServer = "server.fqdn.com",
[bool]$Turbo = $false,
[bool]$Cleanup = $false,
[bool]$VerboseLogging = $false
)

#________________________________________________________
#CHANGE THESE

$Global:DevelopmentInstallCollection = "Client Engineering - Install"
$Global:DevelopmentUnstallCollection = "Client Engineering - Uninstall"

#Logging settings
[bool]$Global:Verbose = [System.Convert]::ToBoolean($VerboseLogging)
$Global:LogFile = Join-Path ($PSScriptRoot) 'ApplicationLifecycle.log' 
$Global:MaxLogSizeInKB = 10240
$Global:ScriptName = 'Application Lifecycle' 


#________________________________________________________



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

If ((Get-Location) -notlike ($CMSite + ":\"))
{
    Set-Location -Path ($CMSite + ":")
}

#Import the function libary.  Remove it first, because in the PowerShell IDE, it caches it.
LogIt -message ("Importing Function module") -component "Main()" -type "Info" -LogFile $LogFile
Remove-Module Functions -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot\Functions -WarningAction SilentlyContinue

#endregion ---------------------------------------

<#
PSEUDO CODE

Get Applications Object

Loop through Applications
{
    If Application is in the Development Folder (or sub folders)
        DP Groups
            Assign to DP Group "Datacenters - All - Internal"
            Assign to DP Group "Regional"
        Deployments
            Create Deployment to Client Engineering groups (machine/user)

    If Application is in the Production Folder (or sub folders)
        DP Groups
            Assign to DP groups above
            Assign to DP Group "DMZ - Internet-Facing"
            Assign to DP Group "Stores - All"
        Deployments
            Remove Deployment to Client Engineering Groups (machine/user)
            Create Device Collection (mandatory Deployment)
            Create User Collection (option Deployment)
        Software Library
            If Manual install
                DO NOT create a deployment to the Software Library
            If Licensed app
                Create deployment to licensed apps
            Else
                Create deployment to Software Library
        SxS
            Create SxS Deployment collection (is this really necessary?)
            Create SxS detection collection

    If Application is in the Retired folder (or sub folders)
        Remove all deployments
        Remove from all DP groups
}


#>

If ($Turbo)
{
    LogIt -message ("Turbo mode enabled.") -component "Main()" -type "Info" -LogFile $LogFile
}

If ($Verbose)
{
    LogIt -message ("Verbose logging enabled. This will product large amounts of logs.") -component "Main()" -type "Warning" -LogFile $LogFile
}

LogIt -message ("Gathering site data") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message ("Getting Device Collections") -component "Main()" -type "Info" -LogFile $LogFile
Write-Progress -Activity "Gathering Site Data" -Status "Getting device collections" -PercentComplete 25
$DeviceCollections = Get-CMDeviceCollection
LogIt -message ("Getting User Collections") -component "Main()" -type "Info" -LogFile $LogFile
Write-Progress -Activity "Gathering Site Data" -Status "Getting user collections" -PercentComplete 50
$UserCollections = Get-CMUserCollection
LogIt -message ("Getting Deployments") -component "Main()" -type "Info" -LogFile $LogFile
Write-Progress -Activity "Gathering Site Data" -Status "Getting deployments" -PercentComplete 75
$Deployments = Get-CMDeployment


$ParsedApplicationName = $ApplicationName.split(",")

ForEach ($SingleApplicationName in $ParsedApplicationName)
{
    $Activity = $SingleApplicationName + " [" + ($ParsedApplicationName.IndexOf($SingleApplicationName)+1) + "/" + $ParsedApplicationName.Count + "]"
    $Status = "Getting Applications for: " + $Activity
    Write-Progress -Activity $Activity -Status $Status -PercentComplete -1

    LogIt -message ("Getting Applications for: " + $Activity) -component "Main()" -type "Info" -LogFile $LogFile

    $Apps = Get-CMApplication -Name $SingleApplicationName

    If ($Cleanup)
    {
        LogIt -message ("Cleanup enabled, skipping application processing.") -component "Main()" -type "Info" -LogFile $LogFile
    }
    Else
    {
        ForEach ($App in $Apps)
        {
            If ($Apps.Count -gt 1)
            {
                $Status = "Processing: " + $App.LocalizedDisplayName + " [" + ($Apps.IndexOf($App)+1) + "/" + $Apps.Count + "]"
            }
            Else
            {
                $Status = "Processing: " + $App.LocalizedDisplayName
            }

            Write-Progress -Activity $Activity -Status $Status -PercentComplete 1

            LogIt -message ($Status) -component "Main()" -type "Info" -LogFile $LogFile

            $CurrentOperation = "Getting Application Folder"
            Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 2
            $AppFolder = Get-ApplicationFolder $CMSite $CMServer $App

            LogIt -message ("App Folder: " + $AppFolder) -component "Main()" -type "Verbose" -LogFile $LogFile

            If ($AppFolder.StartsWith('Production\'))
            {
        <#
            If Application is in the Production Folder (or sub folders)
                DP Groups
                    Assign to DP Group "DMZ - Internet-Facing"
                    Assign to DP Group "Stores - All"
                Deployments
                    Remove Deployment to Client Engineering Groups (machine/user)
                    Create Device Collection (mandatory Deployment)
                Software Library
                    Create deployment to Software Library for app type
                SxS
                    Create SxS Deployment collection
                    Create SxS detection collection
        #>

                LogIt -message ("Distribute Application to Distribution Point Groups") -component "Main()" -type "Verbose" -LogFile $LogFile
                $CurrentOperation = "Distributing Application to Distribution Point Groups"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 20

                Deploy-ApptoDistributionPointGroup $App @("Datacenters - All - Internal","Regional","DMZ - Internet-Facing","Stores - All")

                LogIt -message ("Remove Application deployment for Client Engineering") -component "Main()" -type "Verbose" -LogFile $LogFile
                $CurrentOperation = "Removing Application deployment for Client Engineering"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 30

                Remove-ApplicationtoCollection $App $DevelopmentInstallCollection $Deployments
                Remove-ApplicationtoCollection $App $DevelopmentUnstallCollection $Deployments

                if ($App.LocalizedCategoryInstanceNames -contains "Manual Installation")
                {
                    $Return = Move-CMObject -FolderPath '\Application\Production\Manual Installation' -InputObject $App

                    LogIt -message ("Deploy to Software Library") -component "Main()" -type "Verbose" -LogFile $LogFile
                    $CurrentOperation = "Deploying application to Manual Installation Software Library"
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 50

                    Deploy-ApplicationtoCollection $App 'Software Library - Manual Installation' 'Install' 'Available' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - App-V' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - Licensed Apps' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - Unlicensed Apps' $Deployments

                    $ApplicationDeploymentCollectionLocation = $CMSite + ":\DeviceCollection\Software Distribution\Workstations\Applications - Manual Installation"
                }
                ElseIf ($App.LocalizedCategoryInstanceNames -contains "App-V")
                {
                    $Return = Move-CMObject -FolderPath '\Application\Production\App-V' -InputObject $App

                    LogIt -message ("Deploy to Software Library") -component "Main()" -type "Verbose" -LogFile $LogFile
                    $CurrentOperation = "Deploying application to App-V Software Library"
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 50

                    Remove-ApplicationtoCollection $App 'Software Library - Manual Installation' $Deployments
                    Deploy-ApplicationtoCollection $App 'Software Library - App-V' 'Install' 'Available' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - Licensed Apps' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - Unlicensed Apps' $Deployments

                    $ApplicationDeploymentCollectionLocation = $CMSite + ":\DeviceCollection\Software Distribution\Workstations\Applications - App-V"
                }
                ElseIf ($App.LocalizedCategoryInstanceNames -contains "Licensed")
                {
                    $Return = Move-CMObject -FolderPath '\Application\Production\Licensed' -InputObject $App

                    LogIt -message ("Deploy to Software Library") -component "Main()" -type "Verbose" -LogFile $LogFile
                    $CurrentOperation = "Deploying application to Licensed Software Library"
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 50
                
                    Remove-ApplicationtoCollection $App 'Software Library - Manual Installation' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - App-V' $Deployments
                    Deploy-ApplicationtoCollection $App 'Software Library - Licensed Apps' 'Install' 'Available' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - Unlicensed Apps' $Deployments

                    $ApplicationDeploymentCollectionLocation = $CMSite + ":\DeviceCollection\Software Distribution\Workstations\Applications - Licensed"
                }
                Else
                {
                    $Return = Move-CMObject -FolderPath '\Application\Production' -InputObject $App

                    LogIt -message ("Deploy to Software Library") -component "Main()" -type "Verbose" -LogFile $LogFile
                    $CurrentOperation = "Deploying application to Unlicensed Software Library"
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 50
                
                    Remove-ApplicationtoCollection $App 'Software Library - Manual Installation' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - App-V' $Deployments
                    Remove-ApplicationtoCollection $App 'Software Library - Licensed Apps' $Deployments
                    Deploy-ApplicationtoCollection $App 'Software Library - Unlicensed Apps' 'Install' 'Available' $Deployments

                    $ApplicationDeploymentCollectionLocation = $CMSite + ":\DeviceCollection\Software Distribution\Workstations\Applications - Unlicensed"
                }

                If ($ApplicationDeploymentCollectionLocation)
                {
                    LogIt -message ("Deploy to Applications install collection group") -component "Main()" -type "Verbose" -LogFile $LogFile
                    $CurrentOperation = "Deploying application to install collection"
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 75

                    $CreatedCollection = Create-Collection $App.LocalizedDisplayName $ApplicationDeploymentCollectionLocation $DeviceCollections 'Device'
                    Deploy-ApplicationtoCollection $App $App.LocalizedDisplayName 'Install' 'Required' $Deployments
                }
                Else
                {
                    LogIt -message ("Missing Application Deployment Collection Location") -component "Main()" -type "Error" -LogFile $LogFile
                }

                LogIt -message ("Deploy to SxS collection group") -component "Main()" -type "Verbose" -LogFile $LogFile
                $CurrentOperation = "Deploying application to SxS collections"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 90
                Deploy-ApplicationtoSxS $App $DeviceCollections $Deployments $CMSite

            }
            ElseIf ($AppFolder.StartsWith('Development\'))
            {
        <#
            If Application is in the Development Folder (or sub folders)
                DP Groups
                    Assign to DP Group "Datacenters - All - Internal"
                    Assign to DP Group "Regional"
                Deployments
                    Create Deployment to Client Engineering groups (machine/user)
        #>

                $CurrentOperation = "Deploying application to Distribution Point Groups"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 66
                LogIt -message ("Deploying application to Distribution Point Groups") -component "Main()" -type "Verbose" -LogFile $LogFile
                Deploy-ApptoDistributionPointGroup $App @("Datacenters - All - Internal","Regional")

                $CurrentOperation = "Deploying application to Client Engineering Collections"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 90
                LogIt -message ("Deploying application to Client Engineering Collections") -component "Main()" -type "Verbose" -LogFile $LogFile
                Deploy-ApplicationtoCollection $App $DevelopmentInstallCollection 'Install' 'Available' $Deployments
                Deploy-ApplicationtoCollection $App $DevelopmentUnstallCollection 'Uninstall' 'Required' $Deployments
            }
            ElseIf ($AppFolder.StartsWith('Retired\'))
            {
        <#
            If Application is in the Retired folder (or sub folders)
                Remove all deployments
                Remove from all DP groups
                Retire App
        #>

                LogIt -message ("Cleaning up retired app") -component "Main()" -type "Verbose" -LogFile $LogFile

                $CurrentOperation = "Removing application from Distribution Point Groups"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 25
                LogIt -message ("Removing application from Distribution Point Groups") -component "Main()" -type "Verbose" -LogFile $LogFile
                Remove-ApptoDistributionPointGroup $App @("Datacenters - All - Internal","Regional","DMZ - Internet-Facing","Stores - All")

                $CurrentOperation = "Removing application deployments"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 50
                LogIt -message ("Removing application deployments") -component "Main()" -type "Verbose" -LogFile $LogFile
                $Result = Remove-AllDeployments $App $DeviceCollections $UserCollections

                $CurrentOperation = "Retiring application"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 75
                LogIt -message ("Retiring application") -component "Main()" -type "Verbose" -LogFile $LogFile
                $Result = Suspend-CMApplication -InputObject $App

                $CurrentOperation = "Cleaning up application collections"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 90
                LogIt -message ("Cleaning up application collections") -component "Main()" -type "Verbose" -LogFile $LogFile

                $TestIfCollectionExists = Get-CMDeviceCollection -Name $App.LocalizedDisplayName

                If($TestIfCollectionExists)
                {
                    LogIt -message ("Removing collection " + $App.LocalizedDisplayName) -component "Main()" -type "Warning" -LogFile $LogFile
                    $Result = Remove-CMDeviceCollection -Name $App.LocalizedDisplayName -Force
                }

                $SxSCollectionName = '[SxS Deployment] ' + $App.LocalizedDisplayName
                $TestIfCollectionExists = Get-CMDeviceCollection -Name $SxSCollectionName

                If($TestIfCollectionExists)
                {
                    LogIt -message ("Removing collection " + $SxSCollectionName) -component "Main()" -type "Warning" -LogFile $LogFile
                    $Result = Remove-CMDeviceCollection -Name $SxSCollectionName -Force
                }

            }
            Else
            {
                LogIt -message ("Application is not in Development, Production, or Retired, do not touch.") -component "Main()" -type "Verbose" -LogFile $LogFile
            }
        }
    }

    LogIt -message (" ") -component "ApplicationCleanup()" -type "Info" -LogFile $LogFile
    LogIt -message ("_______________________________________________________________________") -component "ApplicationCleanup()" -type "Info" -LogFile $LogFile


    LogIt -message ("Running Application Cleanup.") -component "ApplicationCleanup()" -type "Info" -LogFile $LogFile

    ForEach ($App in $Apps)
    {
        LogIt -message ("Processing: " + $App.LocalizedDisplayName) -component "ApplicationCleanup()" -type "Info" -LogFile $LogFile

        If ($Apps.Count -gt 1)
        {
            $Status = "Processing: " + $App.LocalizedDisplayName + " [" + ($Apps.IndexOf($App)+1) + "/" + $Apps.Count + "]"
        }
        Else
        {
            $Status = "Processing: " + $App.LocalizedDisplayName
        }

        Write-Progress -Activity $Activity -Status $Status -PercentComplete 1

        $XML = ([xml]$App.SDMPackageXML).AppMgmtDigest.Application
        $RequireRemediation = $false

        $CurrentOperation = "Getting application folder"
        Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 10

        $AppFolder = Get-ApplicationFolder $CMSite $CMServer $App

        LogIt -message ("Application Folder: " + $AppFolder) -component "ApplicationCleanup()" -type "Verbose" -LogFile $LogFile

        If ($AppFolder.StartsWith('Production\'))
        {
            $CurrentOperation = "Performing validation checks"
            Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 25

            If (-not $App.HasContent)
            {
                LogIt -message ("Application is missing content.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }
            
            If (-not $App.IsDeployable)
            {
                LogIt -message ("Application is not deployable.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }

            #Don't check this. We don't care if it's already deployed somewhere else.
            #If (-not $App.IsDeployed)
            #{
            #    LogIt -message ("Application is not deployed.") -component ApplicationCleanup()" -type "Warning" -LogFile $LogFile
            #    $RequireRemediation = $true
            #}
            
            If (-not $App.IsEnabled)
            {
                LogIt -message ("Application is not enabled.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }
            
            If ($App.IsExpired)
            {
                LogIt -message ("Application is expired.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }
            
            If ($App.IsHidden)
            {
                LogIt -message ("Application is hidden.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }
            
            If ($App.IsSuperseded)
            {
                LogIt -message ("Application is superseded") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }
	        
            If ($App.LocalizedDisplayName -match '[^a-zA-Z0-9 _+().-]')
	        {
                LogIt -message ("Application has special characters in the name. Allowed special characters are: _+().-") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
	        }

            If (-not $XML.AutoInstall)
            {
                LogIt -message ("'Allow this application to be installed from the Install Application task sequence action without being deployed' is not checked.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }

            If ($RequireRemediation -eq $true)
            {
                #Move app to development folder for review
                LogIt -message ("Moving Application to \Development\Remediation Required") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $Result = Remove-AllDeployments $App $DeviceCollections $UserCollections
                $Return = Move-CMObject -FolderPath '\Application\Development\Remediation Required' -InputObject $App
                    
                $TestIfCollectionExists = Get-CMDeviceCollection -Name $App.LocalizedDisplayName

                If($TestIfCollectionExists)
                {
                    $CurrentOperation = "Removing collection" + $App.LocalizedDisplayName
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 75
                    LogIt -message ("Removing collection " + $App.LocalizedDisplayName) -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                    $Result = Remove-CMDeviceCollection -Name $App.LocalizedDisplayName -Force
                }

                $SxSCollectionName = '[SxS Deployment] ' + $App.LocalizedDisplayName
                $TestIfCollectionExists = Get-CMDeviceCollection -Name $SxSCollectionName

                If($TestIfCollectionExists)
                {
                    $CurrentOperation = "Removing collection" + $SxSCollectionName
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 90
                    LogIt -message ("Removing collection " + $SxSCollectionName) -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                    $Result = Remove-CMDeviceCollection -Name $SxSCollectionName -Force
                }
            }
            Else
            {
                LogIt -message ("Application has passed all validation tests.") -component "ApplicationCleanup()" -type "Info" -LogFile $LogFile
            }

        }
        ElseIf ($AppFolder.StartsWith('Retired\'))
        {
            $CurrentOperation = "Performing validation checks"
            Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 25

            If ($App.IsDeployed)
            {
                LogIt -message ("Application is deployed.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }

            If (-not $App.IsExpired)
            {
                LogIt -message ("Application is not expired.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }
            
            If ($App.IsHidden)
            {
                LogIt -message ("Application is hidden.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }
	        
            If ($App.LocalizedDisplayName -match '[^a-zA-Z0-9 _+().-]')
            {
                LogIt -message ("Application has special characters in the name. Allowed special characters are: _+().-") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
            }

            If ($App.LocalizedDisplayName.Substring(0,1) -match '[^a-zA-Z0-9]')
	        {
                LogIt -message ("Application name begins with something other than a letter or number.") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $RequireRemediation = $true
	        }

            If ($RequireRemediation -eq $true)
            {
                #Move app to development folder for review
                LogIt -message ("Moving Application to \Application\Development\Remediation Required") -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $Result = Move-CMObject -FolderPath '\Application\Development\Remediation Required' -InputObject $App

                $CurrentOperation = "Removing all deployments"
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 50
                $Result = Remove-AllDeployments $App $DeviceCollections $UserCollections

                $TestIfCollectionExists = Get-CMDeviceCollection -Name $App.LocalizedDisplayName

                If($TestIfCollectionExists)
                {
                    $CurrentOperation = "Removing collection" + $App.LocalizedDisplayName
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 75
                    LogIt -message ("Removing collection " + $App.LocalizedDisplayName) -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                    $Result = Remove-CMDeviceCollection -Name $App.LocalizedDisplayName -Force
                }

                $SxSCollectionName = '[SxS Deployment] ' + $App.LocalizedDisplayName
                $TestIfCollectionExists = Get-CMDeviceCollection -Name $SxSCollectionName

                If($TestIfCollectionExists)
                {
                    $CurrentOperation = "Removing collection" + $SxSCollectionName
                    Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 90
                    LogIt -message ("Removing collection " + $SxSCollectionName) -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                    $Result = Remove-CMDeviceCollection -Name $SxSCollectionName -Force
                }
            }

            Else
            {
                LogIt -message ("Application has passed all validation tests.") -component "ApplicationCleanup()" -type "Info" -LogFile $LogFile
            }
        }
        ElseIf ($AppFolder.StartsWith('Development\'))
        {
            $TestIfCollectionExists = Get-CMDeviceCollection -Name $App.LocalizedDisplayName

            If($TestIfCollectionExists)
            {
                LogIt -message ("Removing collection " + $App.LocalizedDisplayName) -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $CurrentOperation = "Removing collection" + $App.LocalizedDisplayName
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 50
                $Result = Remove-CMDeviceCollection -Name $App.LocalizedDisplayName -Force
            }

            $SxSCollectionName = '[SxS Deployment] ' + $App.LocalizedDisplayName
            $TestIfCollectionExists = Get-CMDeviceCollection -Name $SxSCollectionName

            If($TestIfCollectionExists)
            {
                LogIt -message ("Removing collection " + $SxSCollectionName) -component "ApplicationCleanup()" -type "Warning" -LogFile $LogFile
                $CurrentOperation = "Removing collection" + $SxSCollectionName
                Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -PercentComplete 90
                $Result = Remove-CMDeviceCollection -Name $SxSCollectionName -Force
            }
        }
        Else
        {
            LogIt -message ("Application is not in Development, Production, or Retired, do not touch.") -component "ApplicationCleanup()" -type "Verbose" -LogFile $LogFile
        }
    }

    LogIt -message (" ") -component "ApplicationCleanup()" -type "Info" -LogFile $LogFile
}

LogIt -message (" ") -component "CollectionCleanup()" -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component "CollectionCleanup()" -type "Info" -LogFile $LogFile
LogIt -message (" ") -component "CollectionCleanup()" -type "Info" -LogFile $LogFile

If ($Turbo)
{
    LogIt -message ("Skipping Collection cleanup.") -component "CollectionCleanup()" -type "Info" -LogFile $LogFile
}
Else
{
    LogIt -message ("Running Collection Cleanup.") -component "CollectionCleanup()" -type "Info" -LogFile $LogFile


    ForEach ($DeviceCollection in $DeviceCollections)
    {
        If ($DeviceCollections.Count -gt 1)
        {
            $Activity = "Processing: " + $DeviceCollection.Name + " [" + ($DeviceCollections.IndexOf($DeviceCollection)+1) + "/" + $DeviceCollections.Count + "]"
        }
        Else
        {
            $Activity = "Processing: " + $DeviceCollection.Name
        }


        $Status = " "
        Write-Progress -Activity $Activity -Status $Status -PercentComplete 1


        $Skip = $false


        If ($DeviceCollection.Name -like 'LOC - WKS - *')
        {
            $Skip = $true
        }

        If ($Skip -eq $false)
        {
            $Status = "Get collection folder"
            Write-Progress -Activity $Activity -Status $Status -PercentComplete 10
            $CollectionFolder = Get-CollectionFolder $CMSite $CMServer $DeviceCollection

            If ($CollectionFolder -like '*Software Distribution\Workstations\Applications - *')
            {
                $Status = "Check for matching Application"
                Write-Progress -Activity $Activity -Status $Status -PercentComplete 25
                $AppExists = Get-CMApplication -Name $DeviceCollection.Name


                If ($AppExists.LocalizedDisplayName -contains $DeviceCollection.Name)
                {
                    LogIt -message ("Collection Name: " + $DeviceCollection.Name) -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                    LogIt -message ("Collection Folder: " + $CollectionFolder) -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                    LogIt -message ("Found match between collection and application") -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                }
                Else
                {
                    LogIt -message ("Collection Name: " + $DeviceCollection.Name) -component "CollectionCleanup()" -type "Info" -LogFile $LogFile
                    LogIt -message ("Collection Folder: " + $CollectionFolder) -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                    LogIt -message ("Application no longer exists.") -component "CollectionCleanup()" -type "Warning" -LogFile $LogFile

                    LogIt -message ("Removing device collection.") -component "CollectionCleanup()" -type "Warning" -LogFile $LogFile
                    $Status = "Removing device collection."
                    Write-Progress -Activity $Activity -Status $Status -PercentComplete 75
                    $Result = Remove-CMDeviceCollection -InputObject $DeviceCollection -Force

                }
            }
            ElseIf ($CollectionFolder -like '*Operating System Deployment\SxS*')
            {
                $Status = "Check for matching Application"
                Write-Progress -Activity $Activity -Status $Status -PercentComplete 25

                $DeviceCollectionName = $DeviceCollection.Name -replace "\[SxS Deployment\] ", ""
                $DeviceCollectionName = $DeviceCollectionName -replace "\[SxS Installed\] ", ""

                LogIt -message ("Collection Name: " + $DeviceCollection.Name) -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                LogIt -message ("Collection Folder: " + $CollectionFolder) -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile

                $AppExists = Get-CMApplication -Name $DeviceCollectionName


                If ($AppExists.LocalizedDisplayName -contains $DeviceCollectionName)
                {
                    LogIt -message ("Found match between collection and application") -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                }
                Else
                {
                    LogIt -message ("Application no longer exists.") -component "CollectionCleanup()" -type "Warning" -LogFile $LogFile

                    LogIt -message ("Removing device collection.") -component "CollectionCleanup()" -type "Warning" -LogFile $LogFile
                    $Status = "Removing device collection."
                    Write-Progress -Activity $Activity -Status $Status -PercentComplete 75
                    $Result = Remove-CMDeviceCollection -InputObject $DeviceCollection -Force
                }

                $VariableApplicationID = Get-CMDeviceCollectionVariable -Collection $DeviceCollection -VariableName "ApplicationID"

                Clear-Variable -Name TestVariableApplicationID -Force -ErrorAction SilentlyContinue
                If ($VariableApplicationID.Value)
                {
                    LogIt -message ("Collection Variable Application ID: " + $VariableApplicationID.Value) -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                    $TestVariableApplicationID = Get-CMApplication -Id $VariableApplicationID.Value

                    If ($TestVariableApplicationID.CI_ID -eq $VariableApplicationID.Value)
                    {
                        LogIt -message ("Application ID from collection variable matched to existing application.") -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                    }
                    Else
                    {
                        LogIt -message ("Application ID from collection variable cannot be matched to existing application.") -component "CollectionCleanup()" -type "Warning" -LogFile $LogFile

                        LogIt -message ("Removing device collection.") -component "CollectionCleanup()" -type "Warning" -LogFile $LogFile
                        $Status = "Removing device collection."
                        Write-Progress -Activity $Activity -Status $Status -PercentComplete 85
                        $Result = Remove-CMDeviceCollection -InputObject $DeviceCollection -Force
                    }
                }

                $VariableApplicationName = Get-CMDeviceCollectionVariable -Collection $DeviceCollection -VariableName "ApplicationName"

                If ($VariableApplicationName.Value)
                {
                    LogIt -message ("Collection Variable Application Name: " + $VariableApplicationName.Value) -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                    Clear-Variable -Name TestVariableApplicationName -Force -ErrorAction SilentlyContinue
                    $TestVariableApplicationName = Get-CMApplication -Name $VariableApplicationName.Value

                    If ($TestVariableApplicationName.LocalizedDisplayName -eq $VariableApplicationName.Value)
                    {
                        LogIt -message ("Application Name from collection variable matched to existing application.") -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
                    }
                    Else
                    {
                        LogIt -message ("Application Name from collection variable cannot be matched to existing application.") -component "CollectionCleanup()" -type "Warning" -LogFile $LogFile

                        LogIt -message ("Removing device collection.") -component "CollectionCleanup()" -type "Warning" -LogFile $LogFile
                        $Status = "Removing device collection."
                        Write-Progress -Activity $Activity -Status $Status -PercentComplete 90
                        $Result = Remove-CMDeviceCollection -InputObject $DeviceCollection -Force
                    }
                }
            }
        }
        Else
        {
            LogIt -message ("Skipped collection: " + $DeviceCollection.Name) -component "CollectionCleanup()" -type "Verbose" -LogFile $LogFile
        }
    }
}

LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message ("Processing Complete") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component "Main()" -type "Info" -LogFile $LogFile
LogIt -message (" ") -component "Main()" -type "Info" -LogFile $LogFile


Return
