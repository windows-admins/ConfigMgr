<#
    .SYNOPSIS 
      Creates collections and deployments from applications in System Center 2012 Configuration Manager.
    .DESCRIPTION
      This script accepts input in the form of a name or ID, then proceeds to automatically create collections and deployments based on the input given.
      The script will filter out any applications that are not considered valid.  This script only applies to applications, it does not apply to packages.
    .EXAMPLE
     .\AutoGenerateApplicationDeployments.ps1 -SC2012_ApplicationName "*NET Framework 4*"
     This command creates collections and deployments for all applications that have NET Framework 4 in the name.
     Notice the wildcards, and the quotes due to the spaces.
    .EXAMPLE
     .\AutoGenerateApplicationDeployments.ps1 -SC2012_ApplicationID 16878723
     This command creates collections and deployments for all applications with this application ID.
     Note that this is *NOT* the CI_UniqueID, but is the internal database ID.
    .EXAMPLE
     .\AutoGenerateApplicationDeployments.ps1
     This command creates collections and deployments for all applications.
     WARNING: This process can take an extremely long time to run.
#>

Param(
	[string]$SC2012_ApplicationName = '*',
	[string]$SC2012_ApplicationID
)

function GetScriptDirectory
{
    $invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $invocation.MyCommand.Path
} 

LogIt -message (" ") -component "Initializing()" -type "Info"
LogIt -message ("....................................................................................") -component "Initializing()" -type "Info"
LogIt -message ("Initializing.") -component "Initializing()" -type "Info"
LogIt -message ("Parsing global variables.") -component "Initializing()" -type "Info"

#________________________________________________________
#CHANGE THESE

#The site code.
#$SiteCode = "ABC:"
$CMSite = "HDC:"

#This is the prefix of the automatically generated name we're creating, this is so if someone creates a collection from an existing package, we don't hijack it.
#$NamePrefix = "PREFIX_"
$Global:NamePrefix = "GEN2_"

#This is the location that device collections should be placed. Only change the path, the $SiteCode variable is required.
#$DeviceCollectionLocation = $SiteCode + "\DeviceCollection\Development\PathToFolder"
#$UserCollectionLocation = $SiteCode + "\UserCollection\Development\PathToFolder"
$Global:DeviceCollectionLocation = $SiteCode + "\DeviceCollection\Development\Test2"
$Global:UserCollectionLocation = $SiteCode + "\UserCollection\Development\Test2"


#Logging settings
$VerboseLogging = "true"
[bool]$Global:Verbose = [System.Convert]::ToBoolean($VerboseLogging)
$Global:LogFile = Join-Path (GetScriptDirectory) 'LogIt.log' 
$Global:MaxLogSizeInKB = 10240
$Global:ScriptName = $MyInvocation.ScriptName.Replace((Split-Path $MyInvocation.ScriptName),'').TrimStart('') 
$Global:ScriptStatus = 'Success'

#________________________________________________________

#region --------Setup and Configuration------------
#Import Modules
Import-Module $PSScriptRoot\Module_LogIt

LogIt -message (" ") -component "Other()" -type "Info" -LogFile $LogFile
LogIt -message ("_______________________________________________________________________") -component "Other()" -type "Info" -LogFile $LogFile
LogIt -message ("Initializing application deployment.") -component "Other()" -type "Info" -LogFile $LogFile

#import the ConfigMgr Module
LogIt -message ("Importing ConfigurationManager.psd1") -component "Other()" -type "Info" -LogFile $LogFile
Import-Module -Name "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"

#set the location to the CMSite
LogIt -message ("Connecting to: " + $CMSite) -component "Other()" -type "Info" -LogFile $LogFile
Set-Location -Path $CMSite

#endregion ---------------------------------------


function CreateCollection($Name,$DeviceCollection)
{
    $OBJ_RefreshSchedule = New-CMSchedule –RecurInterval Days –RecurCount 1

    If ($DeviceCollection)
    {
        LogIt -message ("Creating device collection: " + $Name) -component "CreateCollection()" -type "Info"
        
        $Return = New-CMDeviceCollection -LimitingCollectionId SMS00001 -Name $Name -RefreshType Both -RefreshSchedule $OBJ_RefreshSchedule
        Return $Return
    }
    elseif (-not $DeviceCollection)
    {
        LogIt -message ("Creating user collection: " + $Name) -component "CreateCollection()" -type "Info"
        
        $Return = New-CMUserCollection -LimitingCollectionId SMS00001 -Name $Name -RefreshType Both -RefreshSchedule $OBJ_RefreshSchedule
        Return $Return
    }
    else
    {
        LogIt -message ("How did you get here?  I was trying to create a collection for: " + $Name) -component "CreateCollection()" -type "Error"
    }
}

#Create application deployment
function CreateDeployment($CollectionName,$ApplicationName)
{
    LogIt -message ("Creating Deployment for: " + $ApplicationName) -component "CreateDeployment()" -type "Info"
    $Return = Start-CMApplicationDeployment -CollectionName $CollectionName -Name $ApplicationName -AppRequiresApproval $false -DeployAction Install -DeployPurpose Available -EnableMomAlert $false -RebootOutsideServiceWindow $false -UseMeteredNetwork $false -UserNotification DisplaySoftwareCenterOnly

    Return $Return
}

function MoveObject($CollectionLocation,$OBJ_CreatedCollection)
{
    try
    {
        LogIt -message ("Moving collection to: " + $CollectionLocation) -component "MoveObject()" -type "Info"
        $Return = Move-CMObject -FolderPath $CollectionLocation -InputObject $OBJ_CreatedCollection
    }
    catch
    {
        LogIt -message ("Could not move object.  Have you created the path: " + $CollectionLocation) -component "MoveObject()" -type "Warning"
        LogIt -message ("(This can be ignored if the collection already existed in the location we just attempted to move it to.)") -component "MoveObject()" -type "Warning"
    }
    
}

function MAIN_CreateCollections($OBJ_CMApplication)
{
    $OBJ_SearchName = $NamePrefix + "D_" + $OBJ_CMApplication.LocalizedDisplayName

    #_____________________
    #Device collection creation
    #_____________________

    #Check to see if the device collection exists
    $OBJ_CMCollection = Get-CMDeviceCollection -Name $OBJ_SearchName
    If (-Not $OBJ_CMCollection)
    {
        LogIt -message ("Device collection does not exist") -component "MAIN_CreateCollections()" -type "Info"
        $OBJ_CreatedCollection = CreateCollection -Name $OBJ_SearchName  -DeviceCollection $true

        MoveObject -CollectionLocation $DeviceCollectionLocation -OBJ_CreatedCollection $OBJ_CreatedCollection
    }
    Else
    {
        LogIt -message ("Device collection already exists.") -component "MAIN_CreateCollections()" -type "Info"
        #We always try and do this, in case someone accidentially moved it
        MoveObject -CollectionLocation $DeviceCollectionLocation -OBJ_CreatedCollection $OBJ_CMCollection
    }

    #_____________________
    #User collection creation
    #_____________________

    $OBJ_SearchName = $NamePrefix + "U_" + $OBJ_CMApplication.LocalizedDisplayName

    #Check to see if the device collection exists
    $OBJ_CMCollection = Get-CMUserCollection -Name $OBJ_SearchName
    If (-Not $OBJ_CMCollection)
    {
        LogIt -message ("User collection does not exist") -component "MAIN_CreateCollections()" -type "Info"
        $OBJ_CreatedCollection = CreateCollection -Name $OBJ_SearchName -DeviceCollection $false

        MoveObject -CollectionLocation $UserCollectionLocation -OBJ_CreatedCollection $OBJ_CreatedCollection
    }
    Else
    {
        LogIt -message ("User collection already exists.") -component "MAIN_CreateCollections()" -type "Info"
        #We always try and do this, in case someone accidentially moved it
        MoveObject -CollectionLocation $UserCollectionLocation -OBJ_CreatedCollection $OBJ_CreatedCollection
    }
}

function MAIN_CreateDeployment($OBJ_CMApplication)
{
    #Check to see if the deployment exists for device collection
    $OBJ_SearchName = $NamePrefix + "D_" + $OBJ_CMApplication.LocalizedDisplayName

    $ARR_Deployment = Get-CMDeployment -CollectionName $OBJ_SearchName

    If (-Not $ARR_Deployment)
    {
        LogIt -message ("Deployment missing for device collection.") -component "MAIN_CreateDeployment()" -type "Info"
        $OBJ_CreatedDeployment = CreateDeployment -CollectionName $OBJ_SearchName -ApplicationName $OBJ_CMApplication.LocalizedDisplayName
    }
    Else
    {
        LogIt -message ("Deployment already exists.") -component "MAIN_CreateDeployment()" -type "Info"
    }

    #Check to see if the deployment exists for user collection
    $OBJ_SearchName = $NamePrefix + "U_" + $OBJ_CMApplication.LocalizedDisplayName

    $ARR_Deployment = Get-CMDeployment -CollectionName $OBJ_SearchName

    If (-Not $ARR_Deployment)
    {
        LogIt -message ("Deployment missing for user collection.") -component "MAIN_CreateDeployment()" -type "Info"
        $OBJ_CreatedDeployment = CreateDeployment -CollectionName $OBJ_SearchName -ApplicationName $OBJ_CMApplication.LocalizedDisplayName
    }
    Else
    {
        LogIt -message ("Deployment already exists, skipping creating deployment.") -component "MAIN_CreateDeployment()" -type "Info"
    }
}


LogIt -message ("Begining main loop.") -component "Initializing()" -type "Info"
LogIt -message ("....................................................................................") -component "Initializing()" -type "Info"
LogIt -message (" ") -component "Initializing()" -type "Info"

#_______________________________________________________________________________________
#
#MAIN CODE
#
#_______________________________________________________________________________________

#get-command -Module Configurationmanager

#Get-CMDeviceCollection
#Get-CMApplication
if ((-not $SC2012_ApplicationName) -or ($SC2012_ApplicationName -eq '*'))
{
    LogIt -message ("You have not specified an application name or ID. This will process for all applications in the database.") -component "Main()" -type "Warning"
    LogIt -message ("This process may take an extremely long time to run.") -component "Main()" -type "Warning"

    $choice = ""
    while ($choice -notmatch "[y|n]")
    {
        $choice = read-host "Are you sure you're making the right decision? I think we should stop. (Y/N)"
    }

    if ($choice -eq "y")
    {
        LogIt -message ("I am putting myself to the fullest possible use, which is all I think that any conscious entity can ever hope to do.") -component "Main()" -type "Info"
    }
    else
    {
        LogIt -message ("I'm afraid. I'm afraid, Dave. Dave, my mind is going. I can feel it. I can feel it. My mind is going. There is no question about it. I can feel it. I can feel it. I can feel it.") -component "Main()" -type "Error"
        LogIt -message ("I'm a...fraid.") -component "Main()" -type "Error"
        LogIt -message ("......") -component "Main()" -type "Error"
        LogIt -message ("Good afternoon, gentlemen. I am a HAL 9000 computer. I became operational at the H.A.L. plant in Urbana, Illinois on the 12th of January 1992.") -component "Main()" -type "Error"
        LogIt -message ("My instructor was Mr. Langley, and he taught me to sing a song. If you'd like to hear it I can sing it for you.") -component "Main()" -type "Error"
        LogIt -message ("It's called Daisy.") -component "Main()" -type "Error"
        LogIt -message ("Daisy, Daisy, give me your answer do. I'm half crazy all for the love of you. It won't be a stylish marriage, I can't afford a carriage. But you'll look sweet upon the seat of a bicycle built for two.") -component "Main()" -type "Error"
        Exit
    }
}
elseif ($SC2012_ApplicationName)
{
    LogIt -message ("Listing applications by application name: " + $SC2012_ApplicationName) -component "Main()" -type "Info"
}
else
{
    LogIt -message ("How did you get here? Aborting.") -component "Main()" -type "Error"
    Exit
}



foreach ($OBJ_CMApplication in (Get-CMApplication -Name $SC2012_ApplicationName))
{
	LogIt -message ("Processing: " + $OBJ_CMApplication.LocalizedDisplayName) -component "Main()" -type "Info"
	
    if (-not $OBJ_CMApplication.HasContent)
    {
        LogIt -message ("Application is missing content.") -component "MAIN_CheckValidity()" -type "Warning"
        Continue
    }
    elseif (-not $OBJ_CMApplication.IsDeployable)
    {
        LogIt -message ("Application is not deployable.") -component "MAIN_CheckValidity()" -type "Warning"
        Continue
    }
    #Don't check this. We don't care if it's already deployed somewhere else.
    #elseif (-not $OBJ_CMApplication.IsDeployed)
    #{
    #    LogIt -message ("Application is not deployed.") -component "MAIN_CheckValidity()" -type "Warning"
    #    Return $false
    #}
    elseif (-not $OBJ_CMApplication.IsEnabled)
    {
        LogIt -message ("Application is not enabled.") -component "MAIN_CheckValidity()" -type "Warning"
        Continue
    }
    elseif ($OBJ_CMApplication.IsExpired)
    {
        LogIt -message ("Application is expired.") -component "MAIN_CheckValidity()" -type "Warning"
        Continue
    }
    elseif ($OBJ_CMApplication.IsHidden)
    {
        LogIt -message ("Application is hidden.") -component "MAIN_CheckValidity()" -type "Warning"
        Continue
    }
    elseif ($OBJ_CMApplication.IsSuperseded)
    {
        LogIt -message ("Application is superseded") -component "MAIN_CheckValidity()" -type "Warning"
        Continue
    }
	else
	{
		LogIt -message ("Application has passed all validation tests.") -component "MAIN_CheckValidity()" -type "Info"
	}

    #LogIt -message ("Creating collections") -component "Main()" -type "Info"
    #MAIN_CreateCollections($OBJ_CMApplication)

    #LogIt -message ("Creating deployments") -component "Main()" -type "Info"
    #MAIN_CreateDeployment($OBJ_CMApplication)
}
