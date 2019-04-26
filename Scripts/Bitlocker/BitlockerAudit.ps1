$days = 90


$ADComputers = Get-ADComputer -Filter 'PasswordLastSet -ge $days'

# $resultsobj = new-object psobject
$table = New-Object system.Data.DataTable “BLStatus”

$col1 = New-Object system.Data.DataColumn Name,([string])
$col2 = New-Object system.Data.DataColumn Date,([string])
$col3 = New-Object system.Data.DataColumn PasswordID,([string])
$col4 = New-Object system.Data.DataColumn RecoveryPassword,([string])

#Add the Columns
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)

ForEach ($_ in $ADComputers)
{
    $BLStatus = $_.Name | .\Get-BitlockerStatus.ps1

    $row = $table.NewRow()

    Write-Host $_.Name

    If ($_.Name -eq "CLIENT2")
    {
        Write-Host BREAK
    }


    If ($BLStatus)
    {
        #Enter data in the row
        $row.Name = $_.Name
        $row.Date = $BLStatus.Date
        $row.PasswordID = $BLStatus.PasswordID
        $row.RecoveryPassword = $BLStatus.RecoveryPassword


        # $resultsobj | Add-Member -MemberType NoteProperty -Name "Name" -Value $_.Name -PassThru | Add-Member -MemberType NoteProperty -Name "Date" -Value $BLStatus.Date | Add-Member -MemberType NoteProperty -Name "PasswordID" -Value $BLStatus.PasswordID | Add-Member -MemberType NoteProperty -Name "RecoveryPassword" -Value $BLStatus.RecoveryPassword
        # $row = [ordered]@{Name=$_.Name;Date=$BLStatus.Date;PasswordID=$BLStatus.PasswordID;RecoveryPassword=$BLStatus.RecoveryPassword}
    }
    Else
    {
        # $resultsobj | Add-Member -MemberType NoteProperty -Name "Name" -Value $_.Name -PassThru
        # $row = [ordered]@{Name=$_.Name}
        $row.Name = $_.Name
    }

    #Add the row to the table
    $table.Rows.Add($row)


    #Add-Member -in $resultsobj -membertype NoteProperty -name $p.name -value ""
    # $resultsobj | Add-Member -NotePropertyMembers $row
    # $resultsobj | Add-Member -Name $_.Name -membertype NoteProperty -value $row
}

$table | Format-Table -AutoSize | Out-File -FilePath .\BLStatus.txt -Force


