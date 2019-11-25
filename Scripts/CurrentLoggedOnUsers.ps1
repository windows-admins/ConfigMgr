Function Get-QueryUser(){

# Found via: https://stackoverflow.com/questions/39212183/easier-way-to-parse-query-user-in-powershell

Param([switch]$Json) # ALLOWS YOU TO RETURN A JSON OBJECT
    $HT = @()
    $Lines = @(query user).foreach({$(($_) -replace('\s{2,}',','))}) # REPLACES ALL OCCURENCES OF 2 OR MORE SPACES IN A ROW WITH A SINGLE COMMA
    $header=$($Lines[0].split(',').trim())  # EXTRACTS THE FIRST ROW FOR ITS HEADER LINE 
    for($i=1;$i -lt $($Lines.Count);$i++){ # NOTE $i=1 TO SKIP THE HEADER LINE
        $Res = "" | Select-Object $header # CREATES AN EMPTY PSCUSTOMOBJECT WITH PRE DEFINED FIELDS
        $Line = $($Lines[$i].split(',')).foreach({ $_.trim().trim('>') }) # SPLITS AND THEN TRIMS ANOMALIES 
        if($Line.count -eq 5) { $Line = @($Line[0],"$($null)",$Line[1],$Line[2],$Line[3],$Line[4] ) } # ACCOUNTS FOR DISCONNECTED SCENARIO
            for($x=0;$x -lt $($Line.count);$x++){
                $Res.$($header[$x]) = $Line[$x] # DYNAMICALLY ADDS DATA TO $Res
            }
        $HT += $Res # APPENDS THE LINE OF DATA AS PSCUSTOMOBJECT TO AN ARRAY
        Remove-Variable Res # DESTROYS THE LINE OF DATA BY REMOVING THE VARIABLE
    }
        if($Json) {
        $JsonObj = [pscustomobject]@{ $($env:COMPUTERNAME)=$HT } | convertto-json  # CREATES ROOT ELEMENT OF COMPUTERNAME AND ADDS THE COMPLETED ARRAY
            Return $JsonObj
        } else {
            Return $HT
        }
}

{Get-QueryUser | Where-Object {$_.STATE -ne "Active"}}.Count
