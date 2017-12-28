###########################################################  
# Automated repair of SCCM client
########################################################### 
 
#ERROR REPORTING ALL 
Set-StrictMode -Version latest 
 
#---------------------------------------------------------- 
#FUNCTION RepairServices 
#---------------------------------------------------------- 
Function Repair_Services
{ 

   Param(
	[parameter(Mandatory=$true)]
	$ServiceName  # Must be string or array of strings
	)
   
	ForEach ($Service in $ServiceName)
	{
		Write-Host "Verifying $Service"

		Try 
		{ 
			$OBJ_service = Get-Service -Name $Service
			$Test = $True

			# Check nested required services
			ForEach ($OBJ_SubService in $OBJ_service.RequiredServices)
			{
				Repair_Services $OBJ_SubService.Name
			}

			# Start service if it isn't already
			if ($obj_service.Status -ne "Running")
			{
				Write-Host "Starting service."
				Set-Service -Name $obj_service.Name -StartupType Automatic -Status Running
				Start-Service -Name $obj_service.Name
			}
		}
		Catch
		{
			Write-Host "Error fixing service"
		}
	}
}


#---------------------------------------------------------- 
#FUNCTION Register Windows Components 
#---------------------------------------------------------- 
Function Register_Windows_Components 
{ 

   Param(
	[parameter(Mandatory=$true)]
	$Components  # Must be string or array of strings
	)
   
	ForEach ($Component in $Components)
	{
		Write-Host "Verifying $Component"

		Try 
		{ 
			Write-Host "regsvr32.exe /s C:\Windows\system32\$Component"
			regsvr32.exe /s "C:\Windows\system32\$Component"
		}
		Catch
		{
			Write-Host "Error fixing service"
		}
	}
}

#---------------------------------------------------------- 
#FUNCTION Reset DCOM Permissions
#---------------------------------------------------------- 
Function Reset_DCOM_Permissions 
{ 
	$converter = new-object system.management.ManagementClass Win32_SecurityDescriptorHelper

	 $Reg = [WMIClass]"root\default:StdRegProv"
	$newDCOMSDDL = "O:BAG:BAD:(A;;CCDCLCSWRP;;;SY)(A;;CCDCLCSWRP;;;BA)(A;;CCDCLCSWRP;;;IU)"
	$DCOMbinarySD = $converter.SDDLToBinarySD($newDCOMSDDL)
	$Reg.SetBinaryValue(2147483650,"SOFTWARE\Microsoft\Ole","DefaultLaunchPermission", $DCOMbinarySD.binarySD)

	 $Reg = [WMIClass]"root\default:StdRegProv"
	$newDCOMSDDL = "O:BAG:BAD:(A;;CCDCLC;;;WD)(A;;CCDCLC;;;LU)(A;;CCDCLC;;;S-1-5-32-562)(A;;CCDCLC;;;AN)"
	$DCOMbinarySD = $converter.SDDLToBinarySD($newDCOMSDDL)
	$Reg.SetBinaryValue(2147483650,"SOFTWARE\Microsoft\Ole","MachineAccessRestriction", $DCOMbinarySD.binarySD)

	 $Reg = [WMIClass]"root\default:StdRegProv"
	$newDCOMSDDL = "O:BAG:BAD:(A;;CCDCSW;;;WD)(A;;CCDCLCSWRP;;;BA)(A;;CCDCLCSWRP;;;LU)(A;;CCDCLCSWRP;;;S-1-5-32-562)"
	$DCOMbinarySD = $converter.SDDLToBinarySD($newDCOMSDDL)
	$Reg.SetBinaryValue(2147483650,"SOFTWARE\Microsoft\Ole","MachineLaunchRestriction", $DCOMbinarySD.binarySD)
}


#---------------------------------------------------------- 
#FUNCTION Repair WMI
#---------------------------------------------------------- 
Function Repair_WMI
{ 
	winmgmt /verifyrepository
	winmgmt /salvagerepository
}



#---------------------------------------------------------- 
#FUNCTION RepairSCCM 
#---------------------------------------------------------- 
Function Repair_SCCM 
{ 
	Write-Host "Repairing CCM Client"
	Try 
	{ 
		$getProcess = Get-Process -Name ccmrepair* 
		If ($getProcess) 
		{ 
			Write-Host "[WARNING] SCCM Repair is already running. Script will end." 
			Exit 1 
		} 
		Else 
		{ 
			Write-Host "[INFO] Connect to the WMI Namespace on $strComputer." 
			$SMSCli = [wmiclass] "\root\ccm:sms_client" 
			Write-Host "[INFO] Trigger the SCCM Repair on $strComputer." 
			# The actual repair is put in a variable, to trap unwanted output. 
			$repair = $SMSCli.RepairClient() 
			Write-Host "[INFO] Successfully connected to the WMI Namespace and triggered the SCCM Repair" 
		} 
	} 
	Catch 
    	{ 
		# The soft repair trigger failed, so lets fall back to some more hands on methods.
		
        	Stop-Service -Name "CcmExec"

		$CCMPath = (Get-ItemProperty("HKLM:\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties")).$("Local SMS Path")
		$files = get-childitem "$($CCMPath)ServiceData\Messaging\EndpointQueues" -include *.msg,*.que -recurse 
		
		foreach ($file in $files)
		{
		    Try
		    {
			Write-Host "Removing $file.FullName"
			remove-item $file.FullName -Force
		    }
		    Catch
		    {
			Write-Host "Failed to remove $file.FullName"
		    }
		}

		$ccmrepair = "$($CCMPath)ccmrepair.exe"
		$CCMRepairFailed = $False

		# See if CCMRepair exists
		If (Test-Path $ccmrepair)
		{
			Start-Process $ccmrepair
			Start-Sleep -Seconds 5
			$count = 0

			While (Get-Process -Name ccmrepair*)
			{
				if ($count -gt 60){
					Write-Host "We've looped more than 60 times which means this has ran for more than 10 minutes."
					Write-Host "Break out so we don't run forever."
					$CCMRepairFailed = $True
					break
				}
				$count++
				Start-Sleep -Seconds 10
			}
		}
		else
		{
			Write-Host "CCMRepair doesn't exist"
			$CCMRepairFailed = $True
		}

		if ($CCMRepairFailed)
		{
			# CCMRepair failed or doesn't exist, try and fall back to CCMSetup

			$ccmsetup = "$env:SystemRoot\ccmsetup\ccmsetup.exe"
			$ccmsetupargs = "/remediate:client  /log:""$($CCMPath)logs\repair-msi-scripted.log"""
			$CCMSetupFailed = $False

			# See if CCMSetup exists
			If (Test-Path $ccmsetup)
			{
				Start-Process $ccmsetup -ArgumentList $ccmsetupargs
				Start-Sleep -Seconds 5
				$count = 0

				While (Get-Process -Name ccmsetup*)
				{
					if ($count -gt 60){
						Write-Host "We've looped more than 60 times which means this has ran for more than 10 minutes."
						Write-Host "Break out so we don't run forever."
						$CCMSetupFailed = $True
						break
					}
					$count++
					Start-Sleep -Seconds 10
				}
			}
			else
			{
				Write-Host "CCMSetup doesn't exist"
				$CCMSetupFailed = $True
			}
		}

		# Probably should do something if running CCMsetup failed but that's for a future improvement.
		# For now we just give up.
	} 
} 
# RUN SCRIPT  

 
#---------------------------------------------------------- 
#FUNCTION PolicyHandler
#---------------------------------------------------------- 
Function Policy_Handler
{ 
	# Reset the policy, and fetch new ones.

	Try
	{
		$SMSCli = [wmiclass] "\root\ccm:sms_client" 
	
		$trapreturn = $SMSCli.ResetPolicy()
		Start-Sleep -Seconds 60
		$trapreturn = $SMSCli.RequestMachinePolicy()
		Start-Sleep -Seconds 60
		$trapreturn = $SMSCli.EvaluateMachinePolicy
   }
   Catch
   {
		# Do nothing for now, but we should do some sort of handling here.
   }
}

$Services = @(
	"BITS", # Background Intelligent Transfer Service
	"gpsvc",  # Group Policy
	"Winmgmt", # WMI
	"wuauserv", # Windows Update Agent
	"Schedule", # Task Scheduler
	"CcmExec",  # CCM Client
	"CmRcService"  # CCM Remote Connection
)

$DLLComponents = @(
	"actxprxy.dll",
	"atl.dll",
	"Bitsprx2.dll",
	"Bitsprx3.dll",
	"browseui.dll",
	"cryptdlg.dll",
	"dssenh.dll",
	"gpkcsp.dll",
	"initpki.dll",
	"jscript.dll",
	"mshtml.dll",
	"msi.dll",
	"mssip32.dll",
	"msxml3.dll",
	"msxml3r.dll",
	"msxml6.dll",
	"msxml6r.dll",
	"muweb.dll",
	"ole32.dll",
	"oleaut32.dll",
	"Qmgr.dll",
	"Qmgrprxy.dll",
	"rsaenh.dll",
	"sccbase.dll",
	"scrrun.dll",
	"shdocvw.dll",
	"shell32.dll",
	"slbcsp.dll",
	"softpub.dll",
	"urlmon.dll",
	"userenv.dll",
	"vbscript.dll",
	"Winhttp.dll",
	"wintrust.dll",
	"wuapi.dll",
	"wuaueng.dll",
	"wuaueng1.dll",
	"wucltui.dll",
	"wucltux.dll",
	"wups.dll",
	"wups2.dll",
	"wuweb.dll",
	"wuwebv.dll",
	"wbem\wmisvc.dll",
	"Xpob2res.dll"
)

Repair_Services $Services
Register_Windows_Components $DLLComponents
Reset_DCOM_Permissions
Repair_WMI
Repair_SCCM
Policy_Handler
#Finished 
