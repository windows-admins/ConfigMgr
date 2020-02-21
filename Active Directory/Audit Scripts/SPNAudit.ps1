Write-Verbose "Get current Active Directory domain... "
$ADForestInfo = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$ADForestInfoRootDomain = $ADForestInfo.RootDomain
$ADForestInfoRootDomainDN = "DC=" + $ADForestInfoRootDomain -Replace("\.",',DC=')

$ADDomainInfoLGCDN = 'GC://' + $ADForestInfoRootDomainDN

Write-Verbose "Discovering Microsoft SQL Servers in the AD Forest $ADForestInfoRootDomainDN "
$root = [ADSI]$ADDomainInfoLGCDN 
$ADSearcher = new-Object System.DirectoryServices.DirectorySearcher($root,"(serviceprincipalname=*)")
$ADSearcher.SizeLimit = 100000;
$ADSearcher.PageSize = 100000;
$AllADSPNs = $ADSearcher.FindAll()

Write-Verbose "Exporting Active Directory Object Information"
$AllADSPNs.Properties | select-object @{expression={$_.name}; label=’Name’}, @{expression={$_.dnshostname}; label=’DNS Host Name’}, @{expression={$_.cn}; label=’CN’}, @{expression={$_.distinguishedname}; label=’Distinguished Name’}, @{expression={$_.samaccountname}; label=’SAM Account Name’}, @{expression={$_.serviceprincipalname}; label=’Service Principal Name’}, @{expression={$_.objectcategory}; label=’Object Category’}, @{expression={$_.networkaddress}; label=’Network Address’}, @{expression={$_.adspath}; label=’ADS Path’}, @{expression={$_.whencreated}; label=’When Created’} |  Export-Csv -Path ".\ADAudit_Raw_SPNObjectData.csv" -NoTypeInformation

$SPNCount = @{}

ForEach ($_ in $AllADSPNs.Properties.serviceprincipalname)
{
    $SPNName = ($_.Split("/"))[0]

    If ($SPNCount.containsKey($SPNName))
    {
        $SPNCount.($SPNName)++
    }
    Else
    {
        $SPNCount["$SPNName"] = [int]1
    }

}

$SPNCount.GetEnumerator() | Sort-Object Name | Select Name, Value |  Export-Csv -Path ".\ADAudit_SPNCount.csv" -NoTypeInformation

Write-Verbose "Exporting Service Accounts With SPNs"

$ADSearcher = new-Object System.DirectoryServices.DirectorySearcher($root,"(&(objectclass=user)(objectcategory=user)(serviceprincipalname=*))") 
$AllADSPNs = $ADSearcher.FindAll()
$ADSearcher.SizeLimit = 100000;
$ADSearcher.PageSize = 100000;
$AllADSPNs.Properties | select-object @{expression={$_.name}; label=’Name’}, @{expression={$_.dnshostname}; label=’DNS Host Name’}, @{expression={$_.cn}; label=’CN’}, @{expression={$_.distinguishedname}; label=’Distinguished Name’}, @{expression={$_.samaccountname}; label=’SAM Account Name’}, @{expression={$_.serviceprincipalname}; label=’Service Principal Name’}, @{expression={$_.objectcategory}; label=’Object Category’}, @{expression={$_.networkaddress}; label=’Network Address’}, @{expression={$_.adspath}; label=’ADS Path’}, @{expression={$_.whencreated}; label=’When Created’} |  Export-Csv -Path ".\ADAudit_SPNServiceAccounts.csv" -NoTypeInformation
