function LogIt
{
	<#
	    .SYNOPSIS 
	      Creates a log file in the CMTrace format
	    .DESCRIPTION
	    .EXAMPLE
		    Example LogIt function calls
		    LogIt -message ("Starting Logging Example Script") -component "Main()" -type Info 
		    LogIt -message ("Log Warning") -component "Main()" -type Warning 
		    LogIt -message ("Log Error") -component "Main()" -type Error
		    LogIt -message ("Log Verbose") -component "Main()" -type Verbose
		    LogIt -message ("Script Status: " + $Global:ScriptStatus) -component "Main()" -type Info 
		    LogIt -message ("Stopping Logging Example Script") -component "Main()" -type Info
			LogIt -message ("Stopping Logging Example Script") -component "Main()" -type Info -LogFile a.log
	#>

    param (
	    [Parameter(Mandatory=$true)]
	    [string]$message,
	    [Parameter(Mandatory=$true)]
	    [string]$component,
	    [Parameter(Mandatory=$true)]
		[ValidateSet("Info","Warning","Error","Verbose")] 
	    [string]$type,
		[string]$LogFile = $PSScriptRoot + "\LogIt.log"
	)

#    switch ($type)
#    {
#        1 { $type = "Info" }
#        2 { $type = "Warning" }
#        3 { $type = "Error" }
#        4 { $type = "Verbose" }
#    }

    if (($type -eq "Verbose") -and ($Global:Verbose))
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message
    }
    elseif ($type -eq "Error")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message -foreground "red"
    }
    elseif ($type -eq "Warning")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($type + ": " + $message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message -foreground "yellow"
    }
    elseif ($type -eq "Info")
    {
        $toLog = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($message), ($Global:ScriptName + ":" + $component), (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $pid
        $toLog | Out-File -Append -Encoding UTF8 -FilePath $LogFile
        Write-Host $message -foreground "white"
    }
	
#    if (($type -eq 'Warning') -and ($Global:ScriptStatus -ne 'Error'))
#	{
#		$Global:ScriptStatus = $type
#	}
#	
#    if ($type -eq 'Error')
#	{
#		$Global:ScriptStatus = $type
#	}

    if ((Get-Item $LogFile).Length/1KB -gt $MaxLogSizeInKB)
    {
        $log = $LogFile
        Remove-Item ($log.Replace(".log", ".lo_"))
        Rename-Item $LogFile ($log.Replace(".log", ".lo_")) -Force
    }


} 
# SIG # Begin signature block
# MIIOogYJKoZIhvcNAQcCoIIOkzCCDo8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUyOJdzFWZHSPDKLC4qt1aseQO
# B3GgggwyMIIGEzCCBPugAwIBAgIKdTwoJwACAACDHzANBgkqhkiG9w0BAQUFADBJ
# MRUwEwYKCZImiZPyLGQBGRYFbG9jYWwxGTAXBgoJkiaJk/IsZAEZFglVbXBxdWFu
# ZXQxFTATBgNVBAMTDFBEWC1DQS1JU1NVRTAeFw0xNDAyMTMwMTMwNThaFw0xNjEx
# MjExODM2MTVaMB4xHDAaBgNVBAMTE1VtcHF1YSBDb2RlIFNpZ25pbmcwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDSpeI1x0ooSC71cPWGbIWEvdjVRRei
# zNLaH0E4GHTaSwwiVZCydyi6Am7/TGH19HwvGlUdIFk4on1e2eVsFswD40QkEuEx
# j3702U1fisVrWoa1Dbnw9NxS1WHgKMDnUUjctLpGo+RDkojl1bEfS01sn9pGPWze
# wKV4OsDatj9TaRgO8sKHvZh4wF1ud5jzg7IO90I5bdiiBPwVobYYBj/SZOcZVuty
# V3u3v1tzwHdLG6O3UpZiVufOZKHPnV+o5TxxRVB+4UryxI/fo2e8kRl68Mklgt/f
# iu4/MclnFqZGVmYztmJBC5DRhsKvfiVerVF/e8dwi6oqkHRrxNg7PuOzAgMBAAGj
# ggMmMIIDIjA9BgkrBgEEAYI3FQcEMDAuBiYrBgEEAYI3FQiH0IV3gruhbYepiTiH
# 28oDgYOCBoF769QdgsaQfwIBZAIBAzALBgNVHQ8EBAMCB4AwHQYDVR0OBBYEFEdn
# NtjFxIGsA4qJGWC9v6+yOV9SMB8GA1UdIwQYMBaAFJ8Exz/UNFzDElUJsIFHoup8
# DUzdMIIBHwYDVR0fBIIBFjCCARIwggEOoIIBCqCCAQaGgb9sZGFwOi8vL0NOPVBE
# WC1DQS1JU1NVRSgyKSxDTj1QRFgtQ0EtSVNTVUUsQ049Q0RQLENOPVB1YmxpYyUy
# MEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9
# VW1wcXVhbmV0LERDPWxvY2FsP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFz
# ZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludIZCaHR0cDovL3BkeC1j
# YS1pc3N1ZS51bXBxdWFuZXQubG9jYWwvQ2VydEVucm9sbC9QRFgtQ0EtSVNTVUUo
# MikuY3JsMIIBMQYIKwYBBQUHAQEEggEjMIIBHzCBrwYIKwYBBQUHMAKGgaJsZGFw
# Oi8vL0NOPVBEWC1DQS1JU1NVRSxDTj1BSUEsQ049UHVibGljJTIwS2V5JTIwU2Vy
# dmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1VbXBxdWFuZXQs
# REM9bG9jYWw/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRpZmlj
# YXRpb25BdXRob3JpdHkwawYIKwYBBQUHMAKGX2h0dHA6Ly9wZHgtY2EtaXNzdWUu
# dW1wcXVhbmV0LmxvY2FsL0NlcnRFbnJvbGwvUERYLUNBLUlTU1VFLlVtcHF1YW5l
# dC5sb2NhbF9QRFgtQ0EtSVNTVUUoMikuY3J0MDwGA1UdEQQ1MDOgMQYKKwYBBAGC
# NxQCA6AjDCF1bXBxdWFjb2Rlc2lnbmluZ0BVbXBxdWFuZXQubG9jYWwwDQYJKoZI
# hvcNAQEFBQADggEBAIgU/hT5h85mcF9yI+QETfHbiP9xTsJNMGyjUsHwgcshFTLt
# Fog7g1ZMpYC5bUjmnGjB1num0oZvKrr/fl10xHO4RQH6+xiHlj/btexrw+nv0BOU
# 8VvyPoQx7tukUFyiE/0eAf8UV8RPhiCv/SNSJrRb+wi0Ai90wg5VhceIpijRmsJ8
# r5N0XObAHjv9um+PCVjClP5O5mMujHn0ifSuizSwyutpA0TXwYilwYhC3WhW8ENl
# qPfM+jNa+ReKfh8C1fV0nWl8uCWB0xau9Us8nHiR5AJrwexNf0XDZdvGH3UN+VB4
# CJngJH7JcQwgBkDVO8kVZAW0XSQJxxvaW3X1vlwwggYXMIID/6ADAgECAgoq0IH0
# AAAAAAAJMA0GCSqGSIb3DQEBBQUAMFUxCzAJBgNVBAYTAlVTMRQwEgYDVQQKEwtV
# bXBxdWEgQmFuazEUMBIGA1UECxMLVW1wcXVhIEJhbmsxGjAYBgNVBAMTEVVtcHF1
# YW5ldCBSb290IENBMB4XDTEzMTEyMTE4MjYxNVoXDTE2MTEyMTE4MzYxNVowSTEV
# MBMGCgmSJomT8ixkARkWBWxvY2FsMRkwFwYKCZImiZPyLGQBGRYJVW1wcXVhbmV0
# MRUwEwYDVQQDEwxQRFgtQ0EtSVNTVUUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQCUndfocJJrsJvq030nbZu0r5kgQRqsCBT3iPRuYQUo/Fj1/HtnOygI
# b2ICmJPw/rCXoF3Q2YmKJootMc9yHtk1ccoKygG3b8eBS7fODoF7mNngqLSBKUqO
# /+8i+X0V8qqVrMAGkJxJlhksYwoigSUgkyZLzYXJDmvlAVsMJwImnDIBsAxZS3ly
# +583aUunr+rkrejSLDMC2+ykccu9z9mi2srh5EWuhGrDF1CGNBAtaC0hGBUigvlL
# Oj3/hD7hKQ9mHDs2wJlmQhiYOUcn3L8V2O7NmCqACw7ZU6DwY7tGu73/PeOkQ/AS
# MCInnUG1wD2hgVLPTgtbY8PV9hgxtuaPAgMBAAGjggHzMIIB7zAPBgNVHRMBAf8E
# BTADAQH/MB0GA1UdDgQWBBSfBMc/1DRcwxJVCbCBR6LqfA1M3TALBgNVHQ8EBAMC
# AYYwEgYJKwYBBAGCNxUBBAUCAwIAAjAjBgkrBgEEAYI3FQIEFgQUSNR5zJi/NgZI
# ITyLctIuADil9/QwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwHwYDVR0jBBgw
# FoAUC6YAioIFhNuzaaL2FdYgJ1vSyCIwgYEGA1UdHwR6MHgwdqB0oHKGOWh0dHA6
# Ly9wZHgtY2Etcm9vdDAxL0NlcnRFbnJvbGwvVW1wcXVhbmV0JTIwUm9vdCUyMENB
# LmNybIY1ZmlsZTovL1BEWC1DQS1ST09UMDEvQ2VydEVucm9sbC9VbXBxdWFuZXQg
# Um9vdCBDQS5jcmwwgbYGCCsGAQUFBwEBBIGpMIGmMFMGCCsGAQUFBzAChkdodHRw
# Oi8vcGR4LWNhLXJvb3QwMS9DZXJ0RW5yb2xsL1BEWC1DQS1ST09UMDFfVW1wcXVh
# bmV0JTIwUm9vdCUyMENBLmNydDBPBggrBgEFBQcwAoZDZmlsZTovL1BEWC1DQS1S
# T09UMDEvQ2VydEVucm9sbC9QRFgtQ0EtUk9PVDAxX1VtcHF1YW5ldCBSb290IENB
# LmNydDANBgkqhkiG9w0BAQUFAAOCAgEAgURzERD2aBItPlynYU3MLh4OB22IPYwf
# OX0fPe44i2UGHew/JwJfVWJDMG2YBU7HiECDDpwbvJNgRY/GFSoLpedMTrdVRX3J
# 2C/XSHOMifKolWaDbHfAVc4xmyzwv1eys3bDlvoz7nG58hfR4Ks6ZhqmfIzqlqRr
# 2Yln/gJ0JI5JaAoK5/TprSKAmuF2IF8s7ZCQ8bjir27rSFvFaw3Ppmt6UBErUFd6
# kK+ddyVvIsjL11Ivb5VyEj8G0wwaJOjjbMjqmGzq8TOg1Yi8Fh3SVQatsmSGkxKB
# MUk7QdtgZLWg0DqnsLDM44aaoIP6QPsKWBHDFfNEval4UKL4EWxkDMaybmzW30Ai
# 6DvihWapNrIPWn43oGpbQhnhjgdc27ECI4UoF50pWieSZc/2l3o8phrbs+snzNq9
# rxibHljS5Sc8O9IG026vcz/uydskEJVEDbSUbjzbUPKIa8BC2X5eWuzO2UpPeZok
# mpfQ/jxtKzfibcXe3GLNmzshJtfHuA9ejeJcl/VPDyxlorL2durGAcmgj2mSsvgx
# 1wBTh2+aJXvHSMBDixxgrdYvt1Ss6Xw7+WC69vmRbdYeMnQyBd+WXWaFCqet50+G
# gEKhO5Drk9t2lBO5rauqg8NAdx3h7liI6X3qKZ1sFFo2SxVGcVAob4fyWo678r+Q
# GlullckyzoYxggHaMIIB1gIBATBXMEkxFTATBgoJkiaJk/IsZAEZFgVsb2NhbDEZ
# MBcGCgmSJomT8ixkARkWCVVtcHF1YW5ldDEVMBMGA1UEAxMMUERYLUNBLUlTU1VF
# Agp1PCgnAAIAAIMfMAkGBSsOAwIaBQCgWjAYBgorBgEEAYI3AgEMMQowCKACgACh
# AoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMCMGCSqGSIb3DQEJBDEWBBRw
# +HXsnGkAdC56A2Fizg4KKFJc/DANBgkqhkiG9w0BAQEFAASCAQCRmQy181rNLvd0
# iu3Xlkc4eRldWK782jDuVrbiNqjY1YhBtRKYbwMy2mKM6GdkF4T5srG1I0UXiiRL
# LtmHgLzVGXjtJJWmMjV5sBAoDQRyqgvQtVolNYNpK5C7esO2mFRrkHl0tHSzm38c
# hLvgnKtX8vU7+b1QKwlsThTsBQ9PyKfqU+6INxDt6Zt2sAqEjA3qnnajSOwWPJUA
# oLoMg0C33UAl6dnMgZwMmjHGWnId5dK226N00B/T5m/Rcu+goboevHztqqVlyJCS
# 7J9/i6Wnn3B8NNnM9ki0rXfwxEmLp673+t06E2reKXHqDEY0QJcjiGrKT/l2StNU
# 6d6DMy3u
# SIG # End signature block
