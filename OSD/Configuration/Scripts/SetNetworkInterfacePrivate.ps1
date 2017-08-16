$interfaces = (Get-NetConnectionProfile).InterfaceIndex

ForEach ($interface in $interfaces)
{
    powershell Set-NetConnectionProfile -InterfaceIndex $interface -NetworkCategory Private
}
