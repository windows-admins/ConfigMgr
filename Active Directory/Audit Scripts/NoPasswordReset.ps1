Write-Verbose "Get current Active Directory domain... "
$ADForestInfo = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$ADForestInfoRootDomain = $ADForestInfo.RootDomain
$ADForestInfoRootDomainDN = "DC=" + $ADForestInfoRootDomain -Replace("\.",',DC=')

$ADDomainInfoLGCDN = 'GC://' + $ADForestInfoRootDomainDN

Write-Verbose "Discovering Microsoft SQL Servers in the AD Forest $ADForestInfoRootDomainDN "
$root = [ADSI]$ADDomainInfoLGCDN 
$ADSearcher = new-Object System.DirectoryServices.DirectorySearcher($root,"(&(objectclass=user)(objectcategory=user)(useraccountcontrol:1.2.840.113556.1.4.803:=65536))")
$ADSearcher.SizeLimit = 100000;
$ADSearcher.PageSize = 100000;
$AllADSPNs = $ADSearcher.FindAll()

Write-Verbose "Exporting Active Directory Object Information"
$AllADSPNs.Properties | select-object @{expression={$_.name}; label=’Name’}, @{expression={$_.dnshostname}; label=’DNS Host Name’}, @{expression={$_.cn}; label=’CN’}, @{expression={$_.distinguishedname}; label=’Distinguished Name’}, @{expression={$_.samaccountname}; label=’SAM Account Name’}, @{expression={$_.serviceprincipalname}; label=’Service Principal Name’}, @{expression={$_.objectcategory}; label=’Object Category’}, @{expression={$_.networkaddress}; label=’Network Address’}, @{expression={$_.adspath}; label=’ADS Path’}, @{expression={$_.whencreated}; label=’When Created’} |  Export-Csv -Path ".\ADAudit_NoPasswordReset.csv" -NoTypeInformation
