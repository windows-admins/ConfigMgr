
function Get-SqlCommand
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

			if ($PSBoundParameters.ContainsKey('Credential'))
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
			if ($PSBoundParameters.ContainsKey('Credential'))
			{
				$connectionStringElements.'User ID' = $Credential.UserName
				$connectionStringElements.'Password' = $Credential.GetNetworkCredential().Password 
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
			return $connectionString
		}
		catch
		{
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
            if ($PSBoundParameters.ContainsKey('Credential'))
			{
			    $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database -Credential $Credential
            }
            else
            {
                $connectionString = New-SqlConnectionString -ServerName $ServerName -Database $Database 
            }

			$SqlConnection = New-SqlConnection -ConnectionString $connectionString

			$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
			$SqlCmd.CommandText = $Name
			$SqlCmd.Connection = $SqlConnection

            if ($Parameter)
            {
                $SqlCmd.CommandType=[System.Data.CommandType]’StoredProcedure’
                $SqlCmd.Parameters.AddWithValue("@xtext", $Parameter) | Out-Null
            }

            # Write-Host $SqlCmd.Parameters
			$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
			$SqlAdapter.SelectCommand = $SqlCmd
			$DataSet = New-Object System.Data.DataSet
			$SqlAdapter.Fill($DataSet)
            # Write-Host $SqlAdapter
            Return $DataSet.Tables
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}
