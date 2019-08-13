<#
.SYNOPSIS
    Deploy applications to collections, based on Administrative Categories
.DESCRIPTION
    This script deploys applications to specified collections based on the attached Administrative Categories.
    It will then loop through those collections and remove any deployments for apps that no longer bear the
    category queried.

    Originally designed to automatically deploy applications as available to a Helpdesk user collection, and
    Available/Required (for Fast Channel installs) to a Machine Collection.
.INPUTS
    "$deployments" = Edit table with relevant collections, admin categories, and deployment settings
    "$newAppArgs" = Additional settings/defaults for application deployments
    $newAppArgs["DistributionPointGroupName"] = Set your distribution group name
.NOTES
    Name:      Deploy-AppByCategory.ps1
    Author:    Vex
    Contributor: Chris Kibble (On a _massive_ level, thanks Chris!!!)
    Version: 1.0.0
    Release Date: 2019-08-13
#>

# Set the required deployment args per collection
$deployments = @{
    "HelpDesk Deployments"   = @{
        "Category"         = "Helpdesk"
        "Collections"      = @("User Test - HD")
        "ApprovalRequired" = $false
        "UserNotification" = "DisplayAll"
    }
    "JustInTime Deployments" = @{
        "Category"         = "Fast Channel App Deployment"
        "Collections"      = @("Machine Test - Fast Channel App Deploy")
        "ApprovalRequired" = $true       
        "UserNotification" = "DisplaySoftwareCenterOnly"
    }
}

# Grab all of the applications in SCCM that are not Expired (Retired)
$apps = Get-CMApplication -Fast | Where-Object { ($_.IsExpired -eq $false) } | Select-Object LocalizedDisplayName, LocalizedCategoryInstanceNames, CI_UniqueID

# Get the distribution status of all apps
$dists = Get-CMDistributionStatus

# Loop through the $deployemnts
ForEach ($deployment in $deployments.Keys) {
    
    # Set the variables based on the current deployment
    $category = $deployments[$deployment].Category
    $collections = $deployments[$deployment].Collections
    $approval = $deployments[$deployment].ApprovalRequired
    $userNotify = $deployments[$deployment].UserNotification

    # Pull a list of applications with that category
    $appList = $apps.Where( { $_.LocalizedCategoryInstanceNames -contains $category })

    # Loop over each application that should be deployed and ensure it is
    ForEach ($app in $appList) {
        
        $objectId = $(Split-Path $app.CI_UniqueID) -Replace '\\', '/'
        $distCount = ($dists | Where-Object { $_.ObjectID -eq $objectId }).NumberSuccess

        # Loop through the collections, if there are multiples
        ForEach ($collection in $collections) {
            
            $newAppArgs = @{
                "Name"             = $app.LocalizedDisplayName
                "DeployAction"     = "Install"
                "DeployPurpose"    = "Available"
                "ApprovalRequired" = $approval
                "UserNotification" = $userNotify
                "TimeBaseOn"       = "LocalTime"
                "CollectionName"   = $collection
                "WhatIf"           = $true
                "Verbose"          = $true
            }
            
            # If the application has not been distributed, append the distribution parameters to the arg list
            If ($distCount -eq 0) {
                $newAppArgs["DistributeContent"] = $true
                $newAppArgs["DistributionPointGroupName"] = "Contoso Distribution Group"
            }

            If (Get-CMDeployment -SoftwareName $app.LocalizedDisplayName -CollectionName $collection) {
                # Already deployed; do nothing
            }
            Else {
                # Deploy application to the collection
                New-CMApplicationDeployment @newAppArgs

            }

        }
    }

    # Loop over each collection and ensure that there are no deployments that shouldn't be here
    ForEach ($collection in $collections) {
        
        # Grab the deployments on the current looped collection
        $deployedApps = Get-CMDeployment -CollectionName $collection | Select-Object ApplicationName
        # Find apps that aren't in our AppList for this collection
        $badDeployments = $deployedApps.Where( { $_.ApplicationName -notin $appList.LocalizedDisplayName })
        # Loop over apps and remove
        ForEach ($badDeployment in $badDeployments) {
            Remove-CMDeployment -ApplicationName $badDeployment.ApplicationName -CollectionName $collection -Force
        }
    }


}