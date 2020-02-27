[CmdletBinding(SupportsShouldProcess = $true)]
<#
.SYNOPSIS
    Deploy applications to collections, based on Administrative Categories
.DESCRIPTION
    This script deploys applications to specified collections based on the attached Administrative Categories.
    It will then loop through those collections and remove any deployments for apps that no longer bear the
    category queried.

    Originally designed to automatically deploy applications as available to a Helpdesk user collection, and
    Available/Required (for Fast Channel installs) to a Machine Collection
.INPUTS
    "$deployments" = Edit table with relevant collections, admin categories, and deployment settings
    "$newAppArgs" = Additional settings/defaults for application deployments
    $newAppArgs["DistributionPointGroupName"] = Set your distribution group name
.NOTES
    Name:      Deploy-AppByCategory.ps1
    Author:    Vex
    Contributor: Chris Kibble (On a _massive_ level, thanks Chris!!!)
    Contributor: Cody Mathis (On a _miniscule_ level)
    Version: 1.0.2
    Release Date: 2019-08-13
    Updated:
        Version 1.0.1: 2019-08-14
        Version 1.0.2: 2020-02-26
#>

# Site configuration
$ProviderMachineName = "cm.contoso.com" # SMS Provider machine FQDN
$SQLServer = 'cm-sql.contoso.com' # SQL Server that hosts your CM_<SiteCode> database
$SiteCode = (Get-CimInstance -Query "SELECT SiteCode FROM SMS_ProviderLocation WHERE Machine = '$ProviderMachineName'" -Namespace root\SMS -ComputerName $ProviderMachineName).SiteCode
$CMDB = [string]::Format('CM_{0}', $SiteCode)

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
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# store our current location so we can return to it when the script completes
Push-Location

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

# Set the required deployment args per collection
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

# Loop through the $deployemnts
ForEach ($deployment in $deployments.Keys) {

    # Pull a list of applications with that category
    $appList = Invoke-SqlCmd -ServerInstance $SqlServer -Database $CMDB -Query @"
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

    # Loop over each collection and ensure that there are no deployments that shouldn't be here
    ForEach ($collection in $deployments[$deployment].Collections) {
        $GoodAppListSqlArray = [string]::Format("'{0}'", [string]::Join("', '", $appList.LocalizedDisplayName))
        $AppDeploysToRemove = Invoke-SqlCmd -ServerInstance $SqlServer -Database $CMDB -Query @"
        SELECT summ.SoftwareName
            , summ.CollectionID
            , summ.CollectionName
        FROM v_DeploymentSummary summ
        WHERE summ.CollectionName = '$Collection'
            AND summ.SoftwareName NOT IN ($GoodAppListSqlArray)
"@

        # Find apps that aren't in our AppList for this collection and remove the deployment
        foreach ($App in $AppDeploysToRemove) {
            if ($PSCmdlet.ShouldProcess("[CollectionName = '$Collection'] [Application = '$($app.DisplayName)']", "Remove-CMApplicationDeployment")) {
                Write-Verbose "Removing deployment [Application = '$($app.SoftwareName)'] to [CollectionName = '$($app.CollectionName)']"
                Remove-CMApplicationDeployment -Name $App.SoftwareName -CollectionID $App.CollectionID -Force
            }
        }
    }
}

# return to where we were
Pop-Location