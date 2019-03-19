Write-Debug "Loading: MODULE_SQL"

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
                LogIt -message ("New-SqlConnectionString - Found creds: "+$Credential.UserName) -component "MODULE_SQL" -type "DEBUG"

				$connectionStringElements.'User ID' = $Credential.UserName

                If ($Credential.ClearTextPassword)
                {
                    LogIt -message ("Using cleartext password: "+$Credential.ClearTextPassword) -component "MODULE_SQL" -type "DEBUG"
                    $connectionStringElements.'Password' = $Credential.ClearTextPassword
                }
                Else
                {
                    LogIt -message ("Getting Network Creds") -component "MODULE_SQL" -type "DEBUG"
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

            LogIt -message ("Connection string: "+$connectionString) -component "MODULE_SQL" -type "DEBUG"

			return $connectionString
		}
		catch
		{
            Invoke-ErrorHandler -Message "Failed to create SQL connection string" -Exception $_
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
            Invoke-ErrorHandler -Message "Failed to create SQL connection" -Exception $_
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
            if ($PSBoundParameters.ContainsKey('Credential'))
			{
                LogIt -message ("Calling New-SqlConnectionString with credentials") -component "MODULE_SQL" -type "DEBUG"
			    $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database -Credential $Credential
            }
            else
            {
                LogIt -message ("Calling New-SqlConnectionString without credentials") -component "MODULE_SQL" -type "DEBUG"
                $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database 
            }

            LogIt -message ("Calling New-SqlConnection") -component "MODULE_SQL" -type "DEBUG"
			$SqlConnection = New-SqlConnection -ConnectionString $connectionString

			$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
			$SqlCmd.CommandText = $Name
			$SqlCmd.Connection = $SqlConnection

            if ($Parameter)
            {
                # Only enable for extreme debugging circumstances.
                # This will output a very large amount of data which tends to crash CMTrace.
                # LogIt -message ("SQL Parameters passed in: "+$Parameter) -component "MODULE_SQL" -type "DEBUG"
                $SqlCmd.CommandType=[System.Data.CommandType]’StoredProcedure’
                $SqlCmd.Parameters.AddWithValue("@xtext", $Parameter) | Out-Null
            }

            # Write-Host $SqlCmd.Parameters
			$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            LogIt -message ("SelectCommand: "+$SqlCmd.CommandText.ToString()) -component "MODULE_SQL" -type "DEBUG"
			$SqlAdapter.SelectCommand = $SqlCmd
			$DataSet = New-Object System.Data.DataSet
			$SqlAdapter.Fill($DataSet)
            # Write-Host $SqlAdapter
            Return $DataSet.Tables
		}
		catch
		{
            If ($Name)
            {
                Invoke-ErrorHandler -Message "Failed to execute SQL command: "+$Name -Exception $_
            }
            Else
            {
                Invoke-ErrorHandler -Message "Failed to execute SQL command." -Exception $_
            }
		}
	}
}
