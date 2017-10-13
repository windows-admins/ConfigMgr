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
#FUNCTION RepairSCCM 
#---------------------------------------------------------- 
Function Repair_SCCM 
{ 
    Write-Host 
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
          Write-Host "[INFO] Successfully connected to the WMI Namespace and triggered the SCCM Repair on $strComputer." 
          ########## END - PROCESS / PROGRESS CHECK AND RUN 
 
        } 
    } 
    Catch 
    { 
        # The soft repair trigger failed, so lets fall back to some more hands on methods.

        $ccmrepair = "$env:SystemRoot\CCM\ccmrepair.exe"
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
            $ccmsetupargs = "/remediate:client  /log:""$env:SystemRoot\\CCM\logs\repair-msi-scripted.log"""
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

Repair_Services $Services
Repair_SCCM
Policy_Handler
#Finished 
