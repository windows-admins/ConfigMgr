Function Test-FileSystemAccess {
    <#
    .SYNOPSIS
    Check for file system access on a given folder.
    .OUTPUTS
    System.Int32
    0   = ERROR_SUCCESS
    3   = ERROR_PATH_NOT_FOUND
    5   = ERROR_ACCESS_DENIED
    740 = ERROR_ELEVATION_REQUIRED
    .NOTES
        Authors:    Patrick Seymour / Adam Cook
        Contact:    @codaamok
    #>
    param
    (
        [string]$Path,
        [System.Security.AccessControl.FileSystemRights]$Rights
    )

    [System.Security.Principal.WindowsIdentity]$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    [System.Security.Principal.WindowsPrincipal]$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $IsElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ([System.IO.Directory]::Exists($Path))
    {
        try
        {
            [System.Security.AccessControl.FileSystemSecurity]$security = (Get-Item -Path ("FileSystem::{0}" -f $Path) -Force).GetAccessControl()
            if ($security -ne $null)
            {
                [System.Security.AccessControl.AuthorizationRuleCollection]$rules = $security.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
                for([int]$i = 0; $i -lt $rules.Count; $i++)
                {
                    if (($currentIdentity.Groups.Contains($rules[$i].IdentityReference)) -or ($currentIdentity.User -eq $rules[$i].IdentityReference))
                    {
                        [System.Security.AccessControl.FileSystemAccessRule]$fileSystemRule = [System.Security.AccessControl.FileSystemAccessRule]$rules[$i]
                        if ($fileSystemRule.FileSystemRights.HasFlag($Rights))
                        {
                            return 0
                        }
                    }
                }

                if (($IsElevated -eq $false) -And ($rules.Where( { ($_.IdentityReference -eq "S-1-5-32-544") -And ($_.FileSystemRights -eq $Rights) } )))
                {
                    return 740
                }
                else
                {
                    return 5
                }

            }
            else
            {
                return 5
            }
        }
        catch
        {
            return 5
        }
    }
    else
    {
        return 3
    }
}

Test-FileSystemAccess -Path "F:\Applications\notused\elevationrequired" -Rights Read
