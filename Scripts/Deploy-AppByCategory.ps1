<#
    .SYNOPSIS
        Deploy applications to collections, based on Administrative Categories
    .DESCRIPTION
        This script deploys applications to specified collections based on the attached Administrative Categories.
        It will then loop through those collections and remove any deployments for apps that no longer bear the
        category queried.

        Originally designed to automatically deploy applications as available to a Helpdesk user collection, and
        Available/Required (for Fast Channel installs) to a Machine Collection.

        If you want, this script can be be triggered by a status filter rule, with MessageID 30153.

        You can either define your deployments in the script below, or you can provide a JSON file as a parameter,
        which contains an exported hashtable following the deployment template

        @{
            "HelpDesk Deployments"     = @{
                "Category"         = "Helpdesk"
                "Collections"      = @("IT - Helpdesk")
                "ApprovalRequired" = $false
                "DeployAction"     = "Install"
                "DeployPurpose"    = "Available"
                "UserNotification" = "DisplayAll"
            }
            "Fast Channel Deployments" = @{
                "Category"         = "Fast Channel App"
                "Collections"      = @("Deploy - Fast Channel Deployment")
                "ApprovalRequired" = $true
                "DeployAction"     = "Install"
                "DeployPurpose"    = "Available"
                "UserNotification" = "DisplaySoftwareCenterOnly"
            }
        }
    .PARAMETER SiteServer
        The MEMCM Site Server, which will be used to identify other resources as needed.

        IF this script is used as part of a status message filter rule, the variable will be %sitesvr
    .PARAMETER SQLServer
        The MEMCM Site Database Server, which will be queried against.

        IF this script is used as part of a status message filter rule, the variable will be %sqlsvr
    .PARAMETER DistributionPointGroup
        The name of the distribution point group you want to distribute content to in the event of
        an app being deployed that does not have content distributed.
    .PARAMETER DeploymentJSON
        An optional JSON file that should be an exported hash table following the Deployment template noted in the description.

        You can create your deployment template hash table and then run

        $Deployments | ConvertTo-Json | Out-File c:\path\to\test.json
    .INPUTS
        "$deployments" = Edit table with relevant collections, admin categories, and deployment settings
        "$newAppArgs" = Additional settings/defaults for application deployments
        $newAppArgs["DistributionPointGroupName"] = Set your distribution group name
    .NOTES
        Name:      Deploy-AppByCategory.ps1
        Author:    Vex
        Contributor: Chris Kibble (On a _massive_ level, thanks Chris!!!)
        Contributor: Cody Mathis (On a _miniscule_ level)
        Version: 1.0.4
        Release Date: 2019-08-13
        Updated:
            Version 1.0.1: 2019-08-14
            Version 1.0.2: 2020-02-26
            Version 1.0.3: 2020-02-27
            Version 1.0.4: 2020-03-03
#>
#Requires -Modules SqlServer
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)]
    [string]$SiteServer,
    [Parameter(Mandatory = $false)]
    [string]$SQLServer,
    [Parameter(Mandatory = $true)]
    [string]$DistributionPointGroup,
    [Parameter(Mandatory = $false)]
    [ValidateScript( { (Test-Path -LiteralPath $_) -and ($_ -match '\.json$') })]
    [string]$DeploymentJSON
)
#region Gather site configuration, including SiteCode, Site Database Name, and SQLServer if not provided as a parameter
#region gather the Site Code from the SMS Provider
$getSiteCodeSplat = @{
    Query        = "SELECT SiteCode FROM SMS_ProviderLocation WHERE Machine LIKE '$SiteServer%'"
    ComputerName = $SiteServer
    Namespace    = 'root\SMS'
}
$SiteCode = (Get-CimInstance @getSiteCodeSplat).SiteCode
#endregion gather the Site Code from the SMS Provider

switch ($PSBoundParameters.ContainsKey('SQLServer')) {
    #region if a SQLServer is provided, we will use that value, and assume the CMDB to be CM_$SiteCode
    $true {
        $CMDBServer = $SQLServer
        $CMDB = [string]::Format('CM_{0}', $SiteCode)
    }
    #endregion if a SQLServer is provided, we will use that value, and assume the CMDB to be CM_$SiteCode

    #region if a SQLServer is not provided we will attempt to gather the data from the registry
    $false {
        $CMDBInfo = Get-ItemProperty -Path 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SMS\SQL Server\'
        $CMDBServer = $CMDBInfo.Server
        $CMDB = $CMDBInfo.'Database Name'
    }
    #endregion if a SQLServer is not provided we will attempt to gather the data from the registry
}
#endregion Gather site configuration, including SiteCode, Site Database Name, and SQLServer if not provided as a parameter
# Do not change anything below this line

# Import the ConfigurationManager.psd1 module
if ($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}

# Connect to the site's drive if it is not already present
if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer
}

# store our current location so we can return to it when the script completes
Push-Location

# Set the current location to be the site code.
Set-Location "$($SiteCode):\"

switch ($PSBoundParameters.ContainsKey('DeploymentJSON')) {
    #region if a JSON file is provided, we will get the content of the file, convert from JSON, and then convert to a hash table
    $true {
        $deployments = @{ }
        $Categories = (ConvertFrom-Json -InputObject (Out-String -InputObject (Get-Content -Path $DeploymentJSON))).PSObject.Properties
        foreach ($Category in $Categories) {
            $Values = $Category.Value.PSObject.Properties
            $ValueHashTable = @{ }
            foreach ($Value in $Values) {
                $ValueHashTable[$Value.Name] = $Value.Value
            }
            $deployments[$Category.Name] = $ValueHashTable
        }
    }
    #endregion if a JSON file is provided, we will get the content of the file, convert from JSON, and then convert to a hash table

    #region if a JSON file is not provided, the below section should be populated to match your desired category based deployments
    $false {
        $deployments = @{
            "HelpDesk Deployments"     = @{
                Category         = "Helpdesk"
                Collection       = "IT - Helpdesk"
                ApprovalRequired = $false
                DeployAction     = "Install"
                DeployPurpose    = "Available"
                UserNotification = "DisplayAll"
            }
            "Fast Channel Deployments" = @{
                Category         = "Fast Channel App"
                Collection       = "Deploy - Fast Channel Deployment"
                ApprovalRequired = $true
                DeployAction     = "Install"
                DeployPurpose    = "Available"
                UserNotification = "DisplaySoftwareCenterOnly"
            }
        }
    }
    #endregion if a JSON file is not provided, the below section should be populated to match your desired category based deployments
}

#region Loop through the $deployments, adding app deployments that are missing, and removing app deployments that do not match the category
#region pull all applications associated with the specified categories
$CategorySQLArray = [string]::Format("('{0}')", [string]::Join("', '", $deployments.Keys))
$FullAppDeployList = SqlServer\Invoke-SqlCmd -ServerInstance $CMDBServer -Database $CMDB -Query @"
SELECT apps.DisplayName
	, summ.CollectionID
	, summ.CollectionName
    , cats.CategoryInstanceName AS [Category]
	, COUNT(dist.NALPath) AS [TargetedDP]
FROM fn_ListLatestApplicationCIs(1033) apps
    JOIN vAdminCategoryMemberships acm ON acm.ObjectKey = apps.CI_UniqueID
    JOIN v_LocalizedCategories cats ON cats.CategoryInstanceID = acm.CategoryInstanceID
    JOIN v_CIContentPackage package ON package.CI_ID = apps.CI_ID
    JOIN fn_ListDPContents(1033) dist ON dist.PackageID = package.PkgID
	LEFT JOIN v_ApplicationAssignment appass ON appass.ApplicationName = apps.DisplayName
	LEFT JOIN v_DeploymentSummary summ ON summ.AssignmentID = appass.AssignmentID
WHERE apps.IsExpired = 0 AND cats.CategoryInstanceName IN $CategorySQLArray
GROUP BY apps.DisplayName
	, summ.CollectionID
	, summ.CollectionName
    , cats.CategoryInstanceName
"@
$groupedFullAppDeployList = $FullAppDeployList | Group-Object -Property Category -AsHashTable
#endregion pull all applications associated with the specified categories

foreach ($Category in $deployments.Keys) {
    #region Pull a list of applications with that category assigned
    $FullCategoryAppList = $groupedFullAppDeployList.$Category
    #endregion Pull a list of applications with that category assigned


    #region Loop over each application that should be deployed and ensure it is
    if ((Measure-Object -InputObject $FullCategoryAppList).Count -gt 0) {
        $TargetedCollection = $deployments[$Category].Collection

        $groupedFullCategoryAppList = $FullCategoryAppList | Group-Object -Property DisplayName -AsHashTable
        foreach ($app in $groupedFullCategoryAppList.Keys) {
            switch ($TargetedCollection -in ($groupedFullCategoryAppList[$app].CollectionName)) {
                #region App is already deployed
                $true {
                    Write-Verbose "Found that $($App) is already deployed to $TargetedCollection - skipping"
                }
                #endregion App is already deployed
    
                #region Deploy application to the collection
                $false {
                    if ($PSCmdlet.ShouldProcess("[CollectionName = '$TargetedCollection'] [Application = '$($app)']", "New-CMApplicationDeployment")) {
                        Write-Verbose "Deploying [Application = '$($app)'] to [CollectionName = '$TargetedCollection']"
    
                        #region define the splat to pass to New-CMApplicationDeployment
                        If ($groupedFullCategoryAppList[$app].TargetedDP -eq 0) {
                            Write-Verbose "$app found to not be distributed. Will distribute to $DistributionPointGroup as part of app deployment"
                            $newAppArgs["DistributeContent"] = $true
                            $newAppArgs["DistributionPointGroupName"] = $DistributionPointGroup
                        }
        
                        $newAppArgs = @{
                            "Name"             = $app
                            "DeployAction"     = $deployments[$Category].DeployAction
                            "DeployPurpose"    = $deployments[$Category].DeployPurpose
                            "ApprovalRequired" = $deployments[$Category].ApprovalRequired
                            "UserNotification" = $deployments[$Category].UserNotification
                            "TimeBaseOn"       = "LocalTime"
                            "CollectionName"   = $TargetedCollection
                            "Verbose"          = $true
                        }
                        #endregion define the splat to pass to New-CMApplicationDeployment
    
                        New-CMApplicationDeployment @newAppArgs
                    }
                }
                #endregion Deploy application to the collection
            }
        }
    }
    else {
        Write-Verbose "There are no applications associated with [Category = '$($deployments[$deployment].Category)'] to deploy"
    }
    #endregion Loop over each application that should be deployed and ensure it is

    #region Loop over each collection and ensure that there are no deployments that shouldn't be here
    foreach ($collection in $deployments[$Category].Collections) {
        $AppListWhereFilter = switch ($appList.Count) {
            0 {
                [string]::Empty
            }
            default {
                [string]::Format("AND appass.ApplicationName NOT IN ('{0}')", [string]::Join("', '", $appList.DisplayName))
            }
        }
        $AppDeploysToRemove = SqlServer\Invoke-SqlCmd -ServerInstance $CMDBServer -Database $CMDB -Query @"
        SELECT appass.ApplicationName
            , summ.CollectionID
            , summ.CollectionName
        FROM v_DeploymentSummary summ
        JOIN v_ApplicationAssignment appass ON appass.AssignmentID = summ.AssignmentID
            WHERE summ.CollectionName = '$Collection'
            $AppListWhereFilter
"@

        # Find apps that aren't in our AppList for this collection and remove the deployment
        if ((Measure-Object -InputObject $AppDeploysToRemove).Count -gt 0) {
            foreach ($App in $AppDeploysToRemove) {
                if ($PSCmdlet.ShouldProcess("[CollectionName = '$Collection'] [Application = '$($app.ApplicationName)']", "Remove-CMApplicationDeployment")) {
                    Write-Verbose "Removing deployment [Application = '$($app.ApplicationName)'] to [CollectionName = '$($app.CollectionName)']"
                    Remove-CMApplicationDeployment -Name $App.ApplicationName -CollectionID $App.CollectionID -Force
                }
            }
        }
        else {
            Write-Verbose "There are no application deployments to remove for $collection"
        }
    }
    #endregion Loop over each collection and ensure that there are no deployments that shouldn't be here
}
#endregion Loop through the $deployments, adding app deployments that are missing, and removing app deployments that do not match the category

# return to where we were
Pop-Location