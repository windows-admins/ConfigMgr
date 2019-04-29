$interfaces = (Get-NetConnectionProfile).InterfaceIndex

ForEach ($interface in $interfaces)
{
    Set-NetConnectionProfile -InterfaceIndex $interface -NetworkCategory Private
}
