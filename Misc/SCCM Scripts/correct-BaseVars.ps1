<#
Function: This script will fix any issues with gaps in a dynamic variable list used to install ConfigMgr / SCCM applications.
Usage: .\correct-BaseVars.ps1 $NameOfBaseVariable $LengthSuffix
$LengthSuffix should usually be 2 if you use Applications

Author: David O'Brien, david.obrien@gmx.de , Microsoft Enterprise Client Management MVP 2013
Date: 02.01.2014
#>

if ($args.Count -eq 1)
    {
        $BaseVariableName = $args[0]
    }
elseif ($args.Count -eq 2)
    {
        $BaseVariableName = $args[0]
        $LengthSuffix = $args[1]
        
    }

Function Write-Message(	[parameter(Mandatory=$true)]	[ValidateSet("Info", "Warning", "Error", "Verbose")]	[String] $Severity,	[parameter(Mandatory=$true)]	[String] $Message){       if((Test-Path -Path  $LogFile))        {    	    Add-Content -Path "$($LogFile)" -Value "$(([System.DateTime]::Now).ToString()) $Severity - $Message"        }    else        {            New-Item -Path $LogFile -ItemType File        }    Switch ($Severity)        {    	    "Info"		{$FColor="gray"}    	    "Warning"	{$FColor="yellow"}    	    "Error"		{$FColor="red"}    	    "Verbose"	{$FColor="green"}    	    Default		{$FColor="gray"}        }    Write-Output "$(([System.DateTime]::Now).ToString()) $Severity - $Message" -fore $FColor}

$BaseVariableList = @()
#$BaseVariableName = "BasisVariable"
#$LengthSuffix = 2


$objSMSTS = New-Object -ComObject Microsoft.SMS.TSEnvironment

$SMSTSVars = $objSMSTS.GetVariables()

$SMSTSLogPath = $objSMSTS.Value("_SMSTSLogPath")

if (Test-Path $SMSTSLogPath)
    {
        $LogFile = $(Join-Path $SMSTSLogPath CorrectBaseVars.log)
    }

#Writing the Variables to Logfile
Write-Message -Severity Info -Message "This is the Dynamic Variable List BEFORE rebuilding it."

foreach ($Var in $objSMSTS.GetVariables())
    {
        if ( $Var.ToUpper().Substring(0,$var.Length-$LengthSuffix) -eq $BaseVariableName)
            {
                Write-Message -Severity Info -Message "$($Var) = $($objSMSTS.Value($Var))"
                $BaseVariableList += @{$Var=$objSMSTS.Value($Var)}
            }
    }

$objects = @()   
$fixed = @()
$objects = $BaseVariableList

[int]$x = 1
# Writing the variables to Logfile after being reordered
Write-Message -Severity Info -Message "------------------------------------------------------"
Write-Message -Severity Info -Message ""
Write-Message -Severity Info -Message "This is the Dynamic Variable List AFTER rebuilding it."

foreach ($i in $objects) 
{ 
    $Name = "$($BaseVariableName){0:00}" -f $x
    $Value = "$($i.Values)"
    $fixed += @{$Name=$Value}

    Write-Message -Severity Info -Message "$($Name) = $($Value)"

    $x++
    $Name = ""
    $Value = ""
    
}

$BaseVariableListFixed = @()
$BaseVariableListFixed += $fixed



foreach ($BaseVariable in $BaseVariableListFixed)
    {
        
        ""
        $objSMSTS.Value("$($BaseVariable.Keys)") = "$($BaseVariable.Values)"
    }
