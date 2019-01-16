[CmdletBinding(DefaultParameterSetName = "GpoMode")]
Param(
    [Parameter(
		ParameterSetName = "GpoMode",
		Mandatory=$true)]
		[string]$GpoTarget,    # Name of GPO
	[Parameter(
		Mandatory=$true)]
		[string]$DomainTarget,    # Domain name
	[Parameter(
		Mandatory=$true)]
		[string]$SiteCode,    # ConfigMgr site code
	[Parameter(
		Mandatory=$false)]
		[switch]$ExportOnly,    # Switch to disable the creation of CIs and only export to a CAB file
	[Parameter(
		Mandatory=$false)]
		[switch]$Remediate,    # Set remediate non-compliant settings
	[Parameter(
        Mandatory=$false)]
        [ValidateSet('None', 'Informational', 'Warning', 'Critical')]
		[string]$Severity='Informational',    # Rule severity
	[Parameter(
        ParameterSetName = "RsopMode",
		Mandatory=$false)]
		[switch]$ResultantSetOfPolicy,    # Uses Resultant Set of Policy instead of specific GPO for values
	[Parameter(
		ParameterSetName = "GpoMode",
		Mandatory = $false)]
		[switch]$GroupPolicy,    #  Uses a single GPO for values
	[Parameter(
        ParameterSetName = "RsopMode",
		Mandatory=$true)]
		[string]$ComputerName,    # Computer name to be used for RSOP
	[Parameter(
        ParameterSetName = "RsopMode",
		Mandatory=$false)]
		[switch]$LocalPolicy,    # Switch to enable capturing local group policy when using RSOP mode
	[Parameter(
		Mandatory=$false)]
		[switch]$Log    # Switch to enable logging all registry keys and their GPOs to a file
)

# Constants
$MAX_NAME_LENGTH= 255

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$scriptDir = Split-Path -Parent $scriptPath
$startingDrive = (Get-Location).Drive.Name + ":"
$Global:ouPath = $null

if (($GroupPolicy -eq $false) -and ($ResultantSetOfPolicy -eq $false))
{
	$GroupPolicy = $true
}

<#
	Utilizes native GroupPolicy module to query for registry keys assocaited with a given Group Policy
#>
function Get-GPOKeys
{
    param(
        [string]$PolicyName,    # Name of group policy
        [string]$Domain    # Domain name
    )

	If ((Get-Module).Name -contains 'GroupPolicy')
	{
		Write-Verbose "GroupPolicy module already imported."
	}
	Else
	{
		Try
		{
			Import-Module GroupPolicy    # Imports native GroupPolicy PowerShell module
		}
		Catch [Exception]
		{
			Write-Host "Error trying to import GroupPolicy module." -ForegroundColor Red
			Write-Host "Script will exit." -ForegroundColor Red
			pause
			Exit
		}
	}

    Write-Host "Querying for registry keys associated with $PolicyName..."

    $gpoKeys = @("HKLM\Software", "HKLM\System", "HKCU\Software", "HKCU\System")    # Sets registry hives to extract from Group Policy
    $values = @()    
    $keyList = @()
    $newKeyList = @()
    $keyCount = 0
    $prevCount = 0
    $countUp = $true

	# While key count does not increment up
    while ($countUp)
    {
            $prevCount = $keyCount
            $newKeyList = @()
            foreach ($gpoKey in $gpoKeys)
            {
                try
                {
                    $newKeys = (Get-GPRegistryValue -Name $PolicyName -Domain $Domain -Key $gpoKey -ErrorAction Stop).FullKeyPath    # Gets registry keys
                } catch [Exception]
                {
					If ($_.Exception.Message -notlike "*The following Group Policy registry setting was not found:*")
					{
						Write-Host $_.Exception.Message -ForegroundColor Red					
						Break
					}
                }
				# For each key in list of registry keys
                foreach ($nKey in $newKeys)
                {               
					# If key is not already in list
                    if ($keyList -notcontains $nKey)
                    {
                        #Write-Verbose $nKey
                        $keyList += $nKey
                        $keyCount++						
                    }
                    if ($newKeyList -notcontains $nKey)
                    {
                        $newKeyList += $nKey
                    }
                }
            }
            [array]$gpoKeys = $newKeyList
			# If previous key count equals current key count.  (No new keys found; end of list)
            if ($prevCount -eq $keyCount)
            {
                $countUp = $false
            }
    }
    
	If ($newKeys -ne $null)
	{
		foreach ($key in $keyList)
		{
			$values += Get-GPRegistryValue -Name $PolicyName -Domain $Domain -Key $key -ErrorAction SilentlyContinue | select FullKeyPath, ValueName, Value, Type | Where-Object {($_.Value -ne $null) -and ($_.Value.Length -gt 0)} 
		}
		if ($Log)
		{
			foreach ($value in $values)
			{
				Write-Log -RegistryKey $value -GPOName $PolicyName
			}
		}
	}

    $valueCount = $values.Count

    Write-Host "`t$keyCount keys found."
    Write-Host "`t$valueCount values found."

    $values    
}

<#
	Utilizes the ConfigurationManager PowerShell module to create Configuration Item settings based on registry keys
#>
function New-SCCMConfigurationItemSetting
{
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory=$true)]
            [string]$DisplayName,
        [Parameter(
            Mandatory=$false)]
            [string]$Description = "",
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('Int64', 'Double', 'String', 'DateTime', 'Version')]
            [string]$DataType,
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('HKEY_CLASSES_ROOT', 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE', 'HKEY_USERS')]
            [string]$Hive,
        [Parameter(
            Mandatory=$true)]
            [bool]$Is64Bit,
        [Parameter(
            Mandatory=$true)]
            [string]$Key,
        [Parameter(
            Mandatory=$true)]
            [string]$ValueName,
        [Parameter(
            Mandatory=$true)]
            [string]$LogicalName
    )

	If ($DisplayName.Length -gt $MAX_NAME_LENGTH)
	{
		$DisplayName = $DisplayName.Substring(0,$MAX_NAME_LENGTH)
	}

    Write-Verbose "`tCreating setting $DisplayName..."

    $templatePath = "$scriptPath\xmlTemplates"

    $settingXml = [xml](Get-Content $templatePath\setting.xml)
    $settingXml.SimpleSetting.LogicalName = $LogicalName
    $settingXml.SimpleSetting.DataType = $DataType
    $settingXml.SimpleSetting.Annotation.DisplayName.Text = $DisplayName
    $settingXml.SimpleSetting.Annotation.Description.Text = $Description
    $settingXml.SimpleSetting.RegistryDiscoverySource.Hive = $Hive
    $settingXml.SimpleSetting.RegistryDiscoverySource.Is64Bit = $Is64Bit.ToString().ToLower()
    $settingXml.SimpleSetting.RegistryDiscoverySource.Key = $Key
    $settingXml.SimpleSetting.RegistryDiscoverySource.ValueName = $ValueName

    $settingXml    
}

<#
	Utilizes the ConfigurationManager PowerShell module to create Configuration Item rules for previously created CI settings
#>
function New-SCCMConfigurationItemRule
{
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory=$true)]
            [string]$DisplayName,
        [Parameter(
            Mandatory=$false)]
            [string]$Description = "",
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('None', 'Informational', 'Warning', 'Critical')]
            [string]$Severity,
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('Equals', 'NotEquals', 'GreaterThan', 'LessThan', 'Between', 'GreaterEquals', 'LessEquals', 'BeginsWith', `
            'NotBeginsWith', 'EndsWith', 'NotEndsWith', 'Contains', 'NotContains', 'AllOf', 'OneOf', 'NoneOf')]
            [string]$Operator,
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('Registry', 'IisMetabase', 'WqlQuery', 'Script', 'XPathQuery', 'ADQuery', 'File', 'Folder', 'RegistryKey', 'Assembly')]
            [string]$SettingSourceType, 
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('String', 'Boolean', 'DateTime', 'Double', 'Int64', 'Version', 'FileSystemAccessControl', 'RegistryAccessControl', `
            'FileSystemAttribute', 'StringArray', 'Int64Array', 'FileSystemAccessControlArray', 'RegistryAccessControlArray', 'FileSystemAttributeArray')]
            [string]$DataType,
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('Value', 'Count')]
            [string]$Method,
        [Parameter(
            Mandatory=$true)]
            [bool]$Changeable,
        [Parameter(
            Mandatory=$true)]
            [string]$Value,
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('String', 'Boolean', 'DateTime', 'Double', 'Int64', 'Version', 'FileSystemAccessControl', 'RegistryAccessControl', `
            'FileSystemAttribute', 'StringArray', 'Int64Array', 'FileSystemAccessControlArray', 'RegistryAccessControlArray', 'FileSystemAttributeArray')]
            [string]$ValueDataType,
        [Parameter(
            Mandatory=$true)]
            [string]$AuthoringScope,
        [Parameter(
            Mandatory=$true)]
            [string]$SettingLogicalName,
        [Parameter(
            Mandatory=$true)]
            [string]$LogicalName
    )

	If ($DisplayName.Length -gt $MAX_NAME_LENGTH)
	{
		$DisplayName = $DisplayName.Substring(0,$MAX_NAME_LENGTH)
	}

    Write-Verbose "`tCreating rule $DisplayName..."

    $templatePath = "$scriptPath\xmlTemplates"
    $id = "Rule_$([guid]::NewGuid())"
    $resourceID = "ID-$([guid]::NewGuid())"
    #$logicalName = "OperatingSystem_$([guid]::NewGuid())"

    $ruleXml = [xml](Get-Content $templatePath\rule.xml)
    $ruleXml.Rule.Id = $id
    $ruleXml.Rule.Severity = $Severity
    $ruleXml.Rule.Annotation.DisplayName.Text = $DisplayName
    $ruleXml.Rule.Annotation.Description.Text = $Description
    $ruleXml.Rule.Expression.Operator = $Operator
    $ruleXml.Rule.Expression.Operands.SettingReference.AuthoringScopeId = $AuthoringScope
    $ruleXml.Rule.Expression.Operands.SettingReference.LogicalName = $LogicalName
    $ruleXml.Rule.Expression.Operands.SettingReference.SettingLogicalName = $SettingLogicalName
    $ruleXml.Rule.Expression.Operands.SettingReference.SettingSourceType = $SettingSourceType
    $ruleXml.Rule.Expression.Operands.SettingReference.DataType = $ValueDataType
    $ruleXml.Rule.Expression.Operands.SettingReference.Method = $Method
    $ruleXml.Rule.Expression.Operands.SettingReference.Changeable = $Changeable.ToString().ToLower()
    $ruleXml.Rule.Expression.Operands.ConstantValue.DataType = $ValueDataType
    $ruleXml.Rule.Expression.Operands.ConstantValue.Value = $Value

    $ruleXml    
}

<#
	Utilizes the ConfigurationManager PowerShell module to create Configuration Items based on previously created settings and rules
#>
function New-SCCMConfigurationItems
{
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory=$true)]
            [string]$Name,
        [Parameter(
            Mandatory=$false)]
            [string]$Description="",
        [Parameter(
            Mandatory=$true)]
        [ValidateSet('MacOS', 'MobileDevice', 'None', 'WindowsApplication', 'WindowsOS')]
        [string]$CreationType,
        [Parameter(
            Mandatory=$true)]
            [array]$RegistryKeys,
		[Parameter(
            Mandatory=$false)]
        [ValidateSet('None', 'Informational', 'Warning', 'Critical')]
		[string]$Severity='Informational'    # Rule severity
    )
    
	If ((Get-Module).Name -contains 'ConfigurationManager')
	{
		Write-Verbose "ConfigurationManager module already loaded."
	}
	Else
	{
		Try
		{
			Import-Module "$(Split-Path $env:SMS_ADMIN_UI_PATH)\ConfigurationManager"    # Imports ConfigMgr PowerShell module
		}
		Catch [Exception]
		{
			Write-Host "Error trying to import ConfigurationManager module." -ForegroundColor Red
			Write-Host "Script will exit." -ForegroundColor Red
			pause
			Exit
		}
	}

	If ($Name.Length -gt $MAX_NAME_LENGTH)
	{
		$Name = $Name.Substring(0,$MAX_NAME_LENGTH)
	}

    Write-Host "Creating Configuration Item..."

    Set-Location "$SiteCode`:"

    $origName = $Name
    #$tmpFileCi = [System.IO.Path]::GetTempFileName()
	# If ResultantSetOfPolicy option is used use the OU path to name the CI xml
	if ($ResultantSetOfPolicy)
	{
		$ouNoSpace = $Global:ouPath.Replace(" ", "_")
		$ouNoSpace = $ouNoSpace.Replace("/", "_")
		$ciFile = "$scriptPath\$ouNoSpace.xml"
	}
	# If ResultantSetOfPolicy option is not used use the GPO nane to name the CI xml
	else
	{
		$gpoNoSpace = $GpoTarget.Replace(" ", "_")
		$ciFile = "$scriptPath\$gpoNoSpace.xml"
	}

    
    for ($i = 1; $i -le 99; $i++)
    {
        $testCI = Get-CMConfigurationItem -Name $Name
        if ($testCI -eq $null)
        {
            break   
        }
        else
        {
            $Name = $origName + " ($i)"
        }
    }

    $ci = New-CMConfigurationItem -Name $Name -Description $Description -CreationType $CreationType
    $ciXml = [xml]($ci.SDMPackageXML.Replace('<RootComplexSetting/></Settings>', '<RootComplexSetting><SimpleSetting></SimpleSetting></RootComplexSetting></Settings><Rules><Rule></Rule></Rules>'))

    $ciXml.Save($ciFile)

    foreach ($Key in $RegistryKeys)
    {
        $len = ($Key.FullKeyPath.Split("\")).Length
        $keyName = ($Key.FullKeyPath.Split("\"))[$len - 1]
        $valueName = $Key.ValueName
        $value = $Key.Value
        $value = $value -replace "[^\u0030-\u0039\u0041-\u005A\u0061-\u007A]\Z", ""
        $type = $Key.Type
        $dName = $keyName + " - " + $valueName
        $hive = ($Key.FullKeyPath.Split("\"))[0]
        $subKey = ($Key.FullKeyPath).Replace("$hive\","")
        $logicalNameS = "RegSetting_$([guid]::NewGuid())"
        $ruleLogName = $ciXml.DesiredConfigurationDigest.OperatingSystem.LogicalName
        $authScope = $ciXml.DesiredConfigurationDigest.OperatingSystem.AuthoringScopeId
        
		if ($Key.Type -eq "Binary")
		{
			continue
		}
		if ($Key.Type -eq "ExpandString")
        {
            $dataType = "String"
        } elseif($Key.Type -eq "ExpandString")
        {
            $dataType = "String"
        } elseif ($Key.Type -eq "DWord")
        {
            $dataType = "Int64"
        } else
        {
            $dataType = $Key.Type
        }

        if ($value.Length -gt 0)
        {
            $settingXml = New-SCCMConfigurationItemSetting -DisplayName $dName -Description ("$keyName - $valueName") -DataType $dataType -Hive $hive -Is64Bit $false `
                -Key $subKey -ValueName $valueName -LogicalName $logicalNameS
        
            try
            {
                $ruleXml = New-SCCMConfigurationItemRule -DisplayName ("$valueName - $value - $type") -Description "" -Severity $Severity -Operator Equals -SettingSourceType Registry -DataType $dataType -Method Value -Changeable $Remediate `
                    -Value $value -ValueDataType $dataType -AuthoringScope $authScope -SettingLogicalName $logicalNameS -LogicalName $ruleLogName
            }
            catch
            {
                Write-Host Failed: New-SCCMConfigurationItemRule -DisplayName ("$valueName - $value - $type") -Description "" -Severity $Severity -Operator Equals -SettingSourceType Registry -DataType $dataType -Method Value -Changeable $Remediate -Value $value -ValueDataType $dataType -AuthoringScope $authScope -SettingLogicalName $logicalNameS -LogicalName $ruleLogName
                Continue
            }
            $importS = $ciXml.ImportNode($settingXml.SimpleSetting, $true)
            $ciXml.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.AppendChild($importS) | Out-Null
            $importR = $ciXml.ImportNode($ruleXml.Rule, $true)
        
            $ciXml.DesiredConfigurationDigest.OperatingSystem.Rules.AppendChild($importR) | Out-Null
            $ciXml = [xml] $ciXml.OuterXml.Replace(" xmlns=`"`"", "")
            $ciXml.Save($ciFile)
        }
    }

	If ($ExportOnly)
	{
		Write-Host "Deleting Empty Configuration Item..."
		Remove-CMConfigurationItem -Id $ci.CI_ID -Force
		Write-Host "Creating CAB File..."
		if ($ResultantSetOfPolicy)
		{
			Export-CAB -Name $Global:ouPath -Path $ciFile
		}
		else
		{
			Export-CAB -Name $GpoTarget -Path $ciFile
		}
	}
	Else
	{
		Write-Host "Setting DCM Digest..."
		Set-CMConfigurationItem -DesiredConfigurationDigestPath $ciFile -Id $ci.CI_ID
		Remove-Item -Path $ciFile -Force
	}
}

function Export-CAB
{
	Param(
		[string]$Name,
		[string]$Path
	)

	$fileName = $Name.Replace(" ", "_")
	$fileName = $fileName.Replace("/", "_")
	$ddfFile = Join-Path -Path $scriptPath -ChildPath temp.ddf

	$ddfHeader =@"
;*** MakeCAB Directive file
;
.OPTION EXPLICIT      
.Set CabinetNameTemplate=$fileName.cab
.set DiskDirectory1=$scriptPath
.Set MaxDiskSize=CDROM
.Set Cabinet=on
.Set Compress=on
"$Path"
"@

	$ddfHeader | Out-File -filepath $ddfFile -force -encoding ASCII
	makecab /f $ddfFile | Out-Null

	#Remove temporary files
	Remove-Item ($scriptPath + '\temp.ddf') -ErrorAction SilentlyContinue
	Remove-Item ($scriptPath + '\setup.inf') -ErrorAction SilentlyContinue
	Remove-Item ($scriptPath + '\setup.rpt') -ErrorAction SilentlyContinue
	Remove-Item ($scriptPath + '\' + $fileName + '.xml') -ErrorAction SilentlyContinue
}

function Get-RSOP
{
	[CmdletBinding()]
	Param(
		[Parameter(
			Mandatory=$true)]
		[string]$ComputerName
	)

	$tmpXmlFile = [System.IO.Path]::GetTempFileName()    # Creates temp file for rsop results

	try
	{
		Write-Host "Processing Resultant Set of Policy for $ComputerName"
		Get-GPResultantSetOfPolicy -Computer $ComputerName -ReportType xml -Path $tmpXmlFile
	}
	catch [Exception]
	{
		Write-Host "Unable to process Resultant Set of Policy" -ForegroundColor Red
		Pause
		Exit
	}

	$rsop = [xml](Get-Content -Path $tmpXmlFile)
	$domainName = $rsop.Rsop.ComputerResults.Domain
	$rsopKeys = @()
	
	# Loop through all applied GPOs starting with the last applied
	for ($x = $rsop.Rsop.ComputerResults.Gpo.Name.Count; $x -ge 1; $x--)
	{
		$rsopTemp = @()
		# Get GPO name
		$gpoResults = ($rsop.Rsop.ComputerResults.Gpo | Where-Object {($_.Link.AppliedOrder -eq $x) -and ($_.Name -ne "Local Group Policy")} | select Name).Name
		If ($gpoResults -ne $null)
		{
			# If name is not null gets registry keys for that GPO and assign to temp value
			$rsopTemp = Get-GPOKeys -PolicyName $gpoResults -Domain $domainName			
			if ($Global:ouPath -eq $null)
			{
				$Global:ouPath = ($rsop.Rsop.ComputerResults.SearchedSom | Where-Object {$_.Order -eq $x} | select Path).path
			}
		}
		# foreach registry key value in gpo results
		foreach ($key in $rsopTemp)
		{
			# if a value is not already stored with that FullKeyPath and ValueName store that value
			if (($rsopKeys | Where-Object {($_.FullKeyPath -eq $key.FullKeyPath) -and ($_.ValueName -eq $key.ValueName)}) -eq $null)
			{
				$rsopKeys += $key
			}
		}
	}

	Remove-Item -Path $tmpXmlFile -Force   # Deletes temp file

	$rsopKeys
}

function Write-Log
{
	[CmdletBinding()]
	Param(
		[Parameter(
			Mandatory=$true)]
			[array]$RegistryKey,
		[Parameter(
			Mandatory=$true)]
			[string]$GPOName
	)

	[string]$logPath = 'gpo_registry_discovery_' + (Get-Date -Format MMddyyyy) + '.log'
	[string]$outString = $GPOName + "`t" + $RegistryKey.FullKeyPath + "`t" + $RegistryKey.ValueName + "`t" + $RegistryKey.Value + "`t" + $RegistryKey.Type
	Out-File -FilePath .\$logPath -InputObject $outString -Force -Append
}

if ($GroupPolicy)
{
	$gpo = Get-GPOKeys -PolicyName $GpoTarget -Domain $DomainTarget
}
# If ResultantSetOfPolicy option is used remove the first index of the array that contains RSOP information
if ($ResultantSetOfPolicy)
{
	$gpo = Get-RSOP -ComputerName $ComputerName
	if ($gpo[0].RsopMode -ne $null)
	{
		$gpo = $gpo[1..($gpo.Length - 1)]
	}
}

If ($gpo -ne $null)
{
	# If ResultantSetOfPolicy option is used use the OU path to name the CI
	if ($ResultantSetOfPolicy -eq $true)
	{
		$ciName = $Global:ouPath
	}
	# If ResultantSetOfPolicy option is not used use the target GPO to name the CI
	elseif ($GroupPolicy -eq $true)
	{
		$ciName = $GpoTarget
	}

	New-SCCMConfigurationItems -Name $ciName -Description "This is a GPO compliance settings that was automatically created via PowerShell." -CreationType "WindowsOS" -Severity $Severity -RegistryKeys $gpo

	Set-Location $startingDrive

	Write-Host "Complete"
}
Else
{
	Write-Host "** ERROR! The script will terminate. **" -ForegroundColor Red 
}