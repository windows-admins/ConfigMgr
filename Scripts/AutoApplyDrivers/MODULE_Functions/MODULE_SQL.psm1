
function Get-SqlCommand-DEPRECIATED
{
	[OutputType([Microsoft.SqlServer.Management.Smo.StoredProcedure])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

        [Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential		
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

			if ($Credential)
			{
			    $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database -Credential $Credential
            }
            else
            {
                $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database
            }

			$sqlConnection = New-SqlConnection -ConnectionString $connectionString

			$serverInstance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $sqlConnection
			$serverInstance.Databases[$Database].StoredProcedures
		}
		catch
		{
            LogIt -message ("Failed to create SQL connection and server instance") -component "Main()" -type "ERROR" -LogFile $LogFile
            LogIt -message ("$_") -component "Main()" -type "ERROR" -LogFile $LogFile
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function New-SqlConnectionString
{
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			#region Build the connection string. Doing this allows for easy addition or removal of attributes
			$connectionStringElements = [ordered]@{
				Server = "tcp:$ServerName,1433"
				'Initial Catalog' = $Database
				'Persist Security Info' = 'False'
			}

			if ($Credential)
			{
                Write-Host "New-SqlConnectionString - Found creds"
                Write-Host $Credential.UserName
				$connectionStringElements.'User ID' = $Credential.UserName

                If ($Credential.ClearTextPassword)
                {
                    LogIt -message ("Using cleartext password: "+$Credential.ClearTextPassword) -component "Main()" -type "DEBUG" -LogFile $LogFile
                    $connectionStringElements.'Password' = $Credential.ClearTextPassword
                }
                Else
                {
                    LogIt -message ("Getting Network Creds") -component "Main()" -type "DEBUG" -LogFile $LogFile
                    $connectionStringElements.'Password' = $Credential.GetNetworkCredential().Password
                }
			}
			$connectionStringElements += @{
				'MultipleActiveResultSets' = 'False'
				'Encrypt' = 'False'
				'TrustServerCertificate' = 'True'
				'Connection Timeout' = '30'
                'trusted_connection' = 'False'
                'Integrated Security' = 'True'
            }

			$connectionString = ''
			@($connectionStringElements.GetEnumerator()).foreach({
				$connectionString += "$($_.Key)=$($_.Value);"
			})

            LogIt -message ("Connection string") -component "Main()" -type "DEBUG" -LogFile $LogFile
            LogIt -message ($connectionString) -component "Main()" -type "DEBUG" -LogFile $LogFile

			return $connectionString
		}
		catch
		{
            LogIt -message ("Failed to create SQL connection string") -component "Main()" -type "ERROR" -LogFile $LogFile
            LogIt -message ("$_") -component "Main()" -type "ERROR" -LogFile $LogFile
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function New-SqlConnection
{
	[OutputType([System.Data.SqlClient.SqlConnection])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ConnectionString	
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
			$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
			$SqlConnection.ConnectionString = $connectionString
			return $SqlConnection
		}
		catch
		{
            LogIt -message ("Failed to create SQL connection") -component "Main()" -type "ERROR" -LogFile $LogFile
            LogIt -message ("$_") -component "Main()" -type "ERROR" -LogFile $LogFile
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}

function Invoke-SqlCommand
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ServerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[string]$Parameter,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[pscredential]$Credential
	)
	begin
	{
		$ErrorActionPreference = 'Stop'
	}
	process
	{
		try
		{
            Write-Host "Creds: "
            Write-Host $Credential.UserName
            if ($PSBoundParameters.ContainsKey('Credential'))
			{
                LogIt -message ("Calling New-SqlConnectionString with credentials") -component "Main()" -type "DEBUG" -LogFile $LogFile
			    $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database -Credential $Credential
            }
            else
            {
                LogIt -message ("Calling New-SqlConnectionString without credentials") -component "Main()" -type "DEBUG" -LogFile $LogFile
                $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database 
            }

            LogIt -message ("Calling New-SqlConnection") -component "Main()" -type "DEBUG" -LogFile $LogFile
			$SqlConnection = New-SqlConnection -ConnectionString $connectionString

			$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
			$SqlCmd.CommandText = $Name
			$SqlCmd.Connection = $SqlConnection

            if ($Parameter)
            {
                LogIt -message ("SQL Parameters passed in") -component "Main()" -type "DEBUG" -LogFile $LogFile
                $SqlCmd.CommandType=[System.Data.CommandType]’StoredProcedure’
                $SqlCmd.Parameters.AddWithValue("@xtext", $Parameter) | Out-Null
            }

            # Write-Host $SqlCmd.Parameters
			$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            LogIt -message ("SelectCommand: "+$SqlCmd) -component "Main()" -type "DEBUG" -LogFile $LogFile
			$SqlAdapter.SelectCommand = $SqlCmd
			$DataSet = New-Object System.Data.DataSet
			$SqlAdapter.Fill($DataSet)
            # Write-Host $SqlAdapter
            Return $DataSet.Tables
		}
		catch
		{
            LogIt -message ("Failed to execute SQL command") -component "Main()" -type "ERROR" -LogFile $LogFile
            LogIt -message ("SQL: "+$Name) -component "Main()" -type "ERROR" -LogFile $LogFile
            LogIt -message ("$_") -component "Main()" -type "ERROR" -LogFile $LogFile
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}
