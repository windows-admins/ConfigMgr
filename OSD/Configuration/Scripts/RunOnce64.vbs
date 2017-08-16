Const HKLM = &H80000002
 
Const REG_SZ = 1
Const REG_EXPAND_SZ = 2
Const REG_BINARY = 3
Const REG_DWORD = 4
Const REG_MULTI_SZ = 7
 
computer = "."
 
Set shell = CreateObject("WScript.Shell")
 
Set registry = GetObject("winmgmts:" & computer & "rootdefault:StdRegProv")
 
keyPath = "SOFTWAREWow6432NodeMicrosoftWindowsCurrentVersionRunOnce"
registry.EnumValues HKLM, keyPath, valueNames, valueTypes
 
If Not IsNull(valueNames) Then
 
For i = 0 To UBound(valueNames)
text = valueNames(i)
valueName = valueNames(i)
 
Select Case valueTypes(i)
 
Case REG_SZ
registry.GetStringValue HKLM, keyPath, valueName, value
WScript.Echo text & ": "  & value
 
returnCode = shell.Run(value, 1, True)
 
If returnCode = 0 Then
registry.DeleteValue HKLM, keyPath, valueName
End If
 
End Select
 
Next
End If