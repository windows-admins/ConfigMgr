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

        You can either define your deployments in the script below, or you can provide a JSON file as a paramter,
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
        Version: 1.0.3
        Release Date: 2019-08-13
        Updated:
            Version 1.0.1: 2019-08-14
            Version 1.0.2: 2020-02-26
            Version 1.0.3: 2020-02-27
#>
#Requires -Modules SqlServer
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $true)]
    [string]$SiteServer,
    [Parameter(Mandatory = $false)]
    [string]$SQLServer,
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

# Customizations
$initParams = @{ }
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module
if ($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}

# Connect to the site's drive if it is not already present
if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer @initParams
}

# store our current location so we can return to it when the script completes
Push-Location

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

# Set the required deployment args per collection
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
    }
    #endregion if a JSON file is not provided, the below section should be populated to match your desired category based deployments
}

# Loop through the $deployemnts
ForEach ($deployment in $deployments.Keys) {
    # Pull a list of applications with that category
    $appList = SqlServer\Invoke-SqlCmd -ServerInstance $CMDBServer -Database $CMDB -Query @"
        SELECT apps.DisplayName
            , apps.CI_UniqueID
            , COUNT(dist.nalpath) AS [TargetedDP]
        FROM fn_ListLatestApplicationCIs(1033) apps
            JOIN vAdminCategoryMemberships acm ON acm.ObjectKey = apps.CI_UniqueID
            JOIN v_LocalizedCategories cats ON cats.CategoryInstanceID = acm.CategoryInstanceID
            JOIN v_CIContentPackage package ON package.CI_ID = apps.CI_ID
            JOIN fn_ListDPContents(1033) dist ON dist.PackageID = package.PkgID
        WHERE IsExpired = 0 AND cats.CategoryInstanceName = '$($deployments[$deployment].Category)'
        GROUP BY apps.DisplayName
            , apps.CI_UniqueID
"@

    # Loop over each application that should be deployed and ensure it is
    if ((Measure-Object -InputObject $appList).Count -gt 0) {
        ForEach ($app in $appList) {
            # Loop through the collections, if there are multiples
            ForEach ($collection in $deployments[$deployment].Collections) {

                $newAppArgs = @{
                    "Name"             = $app.DisplayName
                    "DeployAction"     = $deployments[$deployment].DeployAction
                    "DeployPurpose"    = $deployments[$deployment].DeployPurpose
                    "ApprovalRequired" = $deployments[$deployment].ApprovalRequired
                    "UserNotification" = $deployments[$deployment].UserNotification
                    "TimeBaseOn"       = "LocalTime"
                    "CollectionName"   = $collection
                    "WhatIf"           = $true
                    "Verbose"          = $true
                }

                # If the application has not been distributed, append the distribution parameters to the arg list
                If ($app.TargetedDP -eq 0) {
                    $newAppArgs["DistributeContent"] = $true
                    $newAppArgs["DistributionPointGroupName"] = "Contoso Distribution Group"
                }

                If (Get-CMDeployment -SoftwareName $app.DisplayName -CollectionName $collection) {
                    Write-Verbose "Found that $($App.DisplayName) is already deployed to $collection - skipping"
                }
                Else {
                    # Deploy application to the collection
                    if ($PSCmdlet.ShouldProcess("[CollectionName = '$Collection'] [Application = '$($app.DisplayName)']", "New-CMApplicationDeployment")) {
                        Write-Verbose "Deploying [Application = '$($app.DisplayName)'] to [CollectionName = '$Collection']"
                        New-CMApplicationDeployment @newAppArgs
                    }
                }
            }
        }
    }
    else {
        Write-Verbose "There are no applications associated with [Category = '$($deployments[$deployment].Category)'] to deploy"
    }

    # Loop over each collection and ensure that there are no deployments that shouldn't be here
    ForEach ($collection in $deployments[$deployment].Collections) {
        $AppListWhereFilter = switch ($appList.Count) {
            0 {
                ' '
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
}

# return to where we were
Pop-Location