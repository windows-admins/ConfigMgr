Function Test-FileSystemAccess {
    <#
    .SYNOPSIS
        Check for file system access on a given folder.
    .OUTPUTS
        [System.Enum]
        ERROR_SUCCESS (0)
        ERROR_PATH_NOT_FOUND (3)
        ERROR_ACCESS_DENIED (5)
        ERROR_ELEVATION_REQUIRED (740)
    .NOTES
        Authors:    Patrick Seymour / Adam Cook
        Contact:    @pseymour / @codaamok
    #>
    param
    (
        [ValidateScript({Test-Path $_ -PathType "Container"})]
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [System.Security.AccessControl.FileSystemRights]$Rights
    )

    enum FileSystemAccessState {
        ERROR_SUCCESS
        ERROR_PATH_NOT_FOUND = 3
        ERROR_ACCESS_DENIED = 5
        ERROR_ELEVATION_REQUIRED = 740
    }

    [System.Security.Principal.WindowsIdentity]$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    [System.Security.Principal.WindowsPrincipal]$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $IsElevated = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $IsInAdministratorsGroup = $currentIdentity.Claims.Value -contains "S-1-5-32-544"

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
                            return [FileSystemAccessState]::ERROR_SUCCESS
                        }
                    }
                }

                if (($IsElevated -eq $false) -And ($IsInAdministratorsGroup -eq $true) -And ($rules.Where( { ($_.IdentityReference -eq "S-1-5-32-544") -And ($_.FileSystemRights.HasFlag($Rights)) } )))
                {
                    # At this point we were able to read ACL and verify Administrators group access, likely because we were qualified by the object set as owner
                    return [FileSystemAccessState]::ERROR_ELEVATION_REQUIRED
                }
                else
                {
                    return [FileSystemAccessState]::ERROR_ACCESS_DENIED
                }

            }
            else
            {
                return [FileSystemAccessState]::ERROR_ACCESS_DENIED
            }
        }
        catch
        {
            return [FileSystemAccessState]::ERROR_ACCESS_DENIED
        }
    }
    else
    {
        return [FileSystemAccessState]::ERROR_PATH_NOT_FOUND
    }
}

Test-FileSystemAccess -Path "C:\Users\acc\Documents\New folder" -Rights Read
