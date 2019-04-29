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
[string]$SC2012_ApplicationName,
[string]$SC2012_ApplicationID
)

function GetScriptDirectory
{
    $invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $invocation.MyCommand.Path
} 

LogIt -message (" ") -component "Initializing()" -type 1
LogIt -message ("....................................................................................") -component "Initializing()" -type 1
LogIt -message ("Initializing.") -component "Initializing()" -type 1
LogIt -message ("Parsing global variables.") -component "Initializing()" -type 1

#________________________________________________________
#CHANGE THESE

#The site code.
#$SiteCode = "ABC:"
$Global:SiteCode = "HDC:"

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
$Global:ScriptName = 'LogIt.ps1' 
$Global:ScriptStatus = 'Success'

#________________________________________________________




#Load the ConfigurationManager Module
LogIt -message ("Loading ConfigurationManager module.") -component "Initializing()" -type 1
Import-Module -Name "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"


function CreateCollection($Name,$DeviceCollection)
{
    $OBJ_RefreshSchedule = New-CMSchedule –RecurInterval Days –RecurCount 1

    If ($DeviceCollection)
    {
        LogIt -message ("Creating device collection: " + $Name) -component "CreateCollection()" -type 1
        
        $Return = New-CMDeviceCollection -LimitingCollectionId SMS00001 -Name $Name -RefreshType Both -RefreshSchedule $OBJ_RefreshSchedule
        Return $Return
    }
    elseif (-not $DeviceCollection)
    {
        LogIt -message ("Creating user collection: " + $Name) -component "CreateCollection()" -type 1
        
        $Return = New-CMUserCollection -LimitingCollectionId SMS00001 -Name $Name -RefreshType Both -RefreshSchedule $OBJ_RefreshSchedule
        Return $Return
    }
    else
    {
        LogIt -message ("How did you get here?  I was trying to create a collection for: " + $Name) -component "CreateCollection()" -type 3
    }
}

#Create application deployment
function CreateDeployment($CollectionName,$ApplicationName)
{
    LogIt -message ("Creating Deployment for: " + $ApplicationName) -component "CreateDeployment()" -type 1
    $Return = Start-CMApplicationDeployment -CollectionName $CollectionName -Name $ApplicationName -AppRequiresApproval $false -DeployAction Install -DeployPurpose Available -EnableMomAlert $false -RebootOutsideServiceWindow $false -UseMeteredNetwork $false -UserNotification DisplaySoftwareCenterOnly

    Return $Return
}

function MoveObject($CollectionLocation,$OBJ_CreatedCollection)
{
    try
    {
        LogIt -message ("Moving collection to: " + $CollectionLocation) -component "MoveObject()" -type 1
        $Return = Move-CMObject -FolderPath $CollectionLocation -InputObject $OBJ_CreatedCollection
    }
    catch
    {
        LogIt -message ("Could not move object.  Have you created the path: " + $CollectionLocation) -component "MoveObject()" -type 2
        LogIt -message ("(This can be ignored if the collection already existed in the location we just attempted to move it to.)") -component "MoveObject()" -type 2
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
        LogIt -message ("Device collection does not exist") -component "MAIN_CreateCollections()" -type 1
        $OBJ_CreatedCollection = CreateCollection -Name $OBJ_SearchName  -DeviceCollection $true

        MoveObject -CollectionLocation $DeviceCollectionLocation -OBJ_CreatedCollection $OBJ_CreatedCollection
    }
    Else
    {
        LogIt -message ("Device collection already exists.") -component "MAIN_CreateCollections()" -type 1
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
        LogIt -message ("User collection does not exist") -component "MAIN_CreateCollections()" -type 1
        $OBJ_CreatedCollection = CreateCollection -Name $OBJ_SearchName -DeviceCollection $false

        MoveObject -CollectionLocation $UserCollectionLocation -OBJ_CreatedCollection $OBJ_CreatedCollection
    }
    Else
    {
        LogIt -message ("User collection already exists.") -component "MAIN_CreateCollections()" -type 1
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
        LogIt -message ("Deployment missing for device collection.") -component "MAIN_CreateDeployment()" -type 1
        $OBJ_CreatedDeployment = CreateDeployment -CollectionName $OBJ_SearchName -ApplicationName $OBJ_CMApplication.LocalizedDisplayName
    }
    Else
    {
        LogIt -message ("Deployment already exists.") -component "MAIN_CreateDeployment()" -type 1
    }

    #Check to see if the deployment exists for user collection
    $OBJ_SearchName = $NamePrefix + "U_" + $OBJ_CMApplication.LocalizedDisplayName

    $ARR_Deployment = Get-CMDeployment -CollectionName $OBJ_SearchName

    If (-Not $ARR_Deployment)
    {
        LogIt -message ("Deployment missing for user collection.") -component "MAIN_CreateDeployment()" -type 1
        $OBJ_CreatedDeployment = CreateDeployment -CollectionName $OBJ_SearchName -ApplicationName $OBJ_CMApplication.LocalizedDisplayName
    }
    Else
    {
        LogIt -message ("Deployment already exists, skipping creating deployment.") -component "MAIN_CreateDeployment()" -type 1
    }
}

function MAIN_CheckValidity($OBJ_CMApplication)
{
    if (-not $OBJ_CMApplication.HasContent)
    {
        LogIt -message ("Application is missing content.") -component "MAIN_CheckValidity()" -type 2
        Return $false
    }
    elseif (-not $OBJ_CMApplication.IsDeployable)
    {
        LogIt -message ("Application is not deployable.") -component "MAIN_CheckValidity()" -type 2
        Return $false
    }
    #Don't check this. We don't care if it's already deployed somewhere else.
    #elseif (-not $OBJ_CMApplication.IsDeployed)
    #{
    #    LogIt -message ("Application is not deployed.") -component "MAIN_CheckValidity()" -type 2
    #    Return $false
    #}
    elseif (-not $OBJ_CMApplication.IsEnabled)
    {
        LogIt -message ("Application is not enabled.") -component "MAIN_CheckValidity()" -type 2
        Return $false
    }
    elseif ($OBJ_CMApplication.IsExpired)
    {
        LogIt -message ("Application is expired.") -component "MAIN_CheckValidity()" -type 2
        Return $false
    }
    elseif ($OBJ_CMApplication.IsHidden)
    {
        LogIt -message ("Application is hidden.") -component "MAIN_CheckValidity()" -type 2
        Return $false
    }
    elseif ($OBJ_CMApplication.IsSuperseded)
    {
        LogIt -message ("Application is superseded") -component "MAIN_CheckValidity()" -type 2
        Return $false
    }
    else
    {
        Return $true
    }

}

function LogIt
{
    param (
    [Parameter(Mandatory=$true)]
    $message,
    [Parameter(Mandatory=$true)]
    $component,
    [Parameter(Mandatory=$true)]
    $type )

    switch ($type)
    {
        1 { $type = "Info" }
        2 { $type = "Warning" }
        3 { $type = "Error" }
        4 { $type = "Verbose" }
    }

    if (($type -eq "Verbose") -and ($Global:Verbose))
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath ("filesystem::{0}" -f $Global:LogFile)
        Write-Host $message
    }
    elseif ($type -ne "Verbose")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath ("filesystem::{0}" -f $Global:LogFile)
        Write-Host $message
    }
    if (($type -eq 'Warning') -and ($Global:ScriptStatus -ne 'Error')) { $Global:ScriptStatus = $type }
    if ($type -eq 'Error') { $Global:ScriptStatus = $type }

    if ((Get-Item $Global:LogFile).Length/1KB -gt $Global:MaxLogSizeInKB)
    {
        $log = $Global:LogFile
        Remove-Item ($log.Replace(".log", ".lo_"))
        Rename-Item $Global:LogFile ($log.Replace(".log", ".lo_")) -Force
    }

    #Example LogIt function calls
    #LogIt -message ("Starting Logging Example Script") -component "Main()" -type 1 
    #LogIt -message ("Log Warning") -component "Main()" -type 2 
    #LogIt -message ("Log Error") -component "Main()" -type 3
    #LogIt -message ("Log Verbose") -component "Main()" -type 4
    #LogIt -message ("Script Status: " + $Global:ScriptStatus) -component "Main()" -type 1 
    #LogIt -message ("Stopping Logging Example Script") -component "Main()" -type 1
} 





LogIt -message ("Begining main loop.") -component "Initializing()" -type 1
LogIt -message ("....................................................................................") -component "Initializing()" -type 1
LogIt -message (" ") -component "Initializing()" -type 1

#_______________________________________________________________________________________
#
#MAIN CODE
#
#_______________________________________________________________________________________

#get-command -Module Configurationmanager

CD $SiteCode
#Get-CMDeviceCollection
#Get-CMApplication


if (-not $SC2012_ApplicationName -and -not $SC2012_ApplicationID)
{

    LogIt -message ("You have not specified an application name or ID. This will process for all applications in the database.") -component "Main()" -type 2
    LogIt -message ("This process may take an extremely long time to run.") -component "Main()" -type 2

    $choice = ""
    while ($choice -notmatch "[y|n]")
    {
        $choice = read-host "Are you sure you're making the right decision? I think we should stop. (Y/N)"
    }

    if ($choice -eq "y")
    {
        LogIt -message ("I am putting myself to the fullest possible use, which is all I think that any conscious entity can ever hope to do.") -component "Main()" -type 1
        $Arr_CMApplication = Get-CMApplication
    }
    else
    {
        LogIt -message ("I'm afraid. I'm afraid, Dave. Dave, my mind is going. I can feel it. I can feel it. My mind is going. There is no question about it. I can feel it. I can feel it. I can feel it.") -component "Main()" -type 3
        LogIt -message ("I'm a...fraid.") -component "Main()" -type 3
        LogIt -message ("......") -component "Main()" -type 3
        LogIt -message ("Good afternoon, gentlemen. I am a HAL 9000 computer. I became operational at the H.A.L. plant in Urbana, Illinois on the 12th of January 1992.") -component "Main()" -type 3
        LogIt -message ("My instructor was Mr. Langley, and he taught me to sing a song. If you'd like to hear it I can sing it for you.") -component "Main()" -type 3
        LogIt -message ("It's called Daisy.") -component "Main()" -type 3
        LogIt -message ("Daisy, Daisy, give me your answer do. I'm half crazy all for the love of you. It won't be a stylish marriage, I can't afford a carriage. But you'll look sweet upon the seat of a bicycle built for two.") -component "Main()" -type 3
        Exit
    }
}
elseif ($SC2012_ApplicationID)
{
    LogIt -message ("Listing applications by application ID: " + $SC2012_ApplicationID) -component "Main()" -type 1
    $ARR_CMApplication = Get-CMApplication -ID $SC2012_ApplicationID
}
elseif ($SC2012_ApplicationName)
{
    LogIt -message ("Listing applications by application name: " + $SC2012_ApplicationName) -component "Main()" -type 1
    $ARR_CMApplication = Get-CMApplication -Name $SC2012_ApplicationName
}
else
{
    LogIt -message ("How did you get here? Aborting.") -component "Main()" -type 3
    Exit
}


#****DEBUG**** REMOVE THIS
#Write-Host "We are still in debug mode."
#$ARR_CMApplication=Get-CMApplication -Name "*NET Framework 4*"
#$Arr_CMApplication=Get-CMApplication

foreach ($OBJ_CMApplication in $ARR_CMApplication)
{
    LogIt -message ("   ") -component "Main()" -type 1
    LogIt -message ("_____________________________________________________") -component "Main()" -type 1
	LogIt -message ("Processing: " + $OBJ_CMApplication.LocalizedDisplayName) -component "Main()" -type 1


    $Return = MAIN_CheckValidity($OBJ_CMApplication)

    if ($Return)
    {
        LogIt -message ("Creating collections") -component "Main()" -type 1
        MAIN_CreateCollections($OBJ_CMApplication)

        LogIt -message ("Creating deployments") -component "Main()" -type 1
        MAIN_CreateDeployment($OBJ_CMApplication)
    }
    else
    {
        LogIt -message ("Package validation not passed.  Check application status if this is not an expected warning.") -component "Main()" -type 2
    }
    
}

