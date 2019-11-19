([wmiclass]'ROOT\ccm:SMS_Client').ResetPolicy(1) >> $null
Start-Sleep -Second 3
([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000040}') >> $null
([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000021}') >> $null
Write-Output "SCCM Client Policy Reset"
