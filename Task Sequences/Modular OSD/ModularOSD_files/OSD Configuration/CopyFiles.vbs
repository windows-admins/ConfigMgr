' //***************************************************************************
' // ***** Script Header *****
' //
' // Solution:  File copy relative to script location
' // File:      CopyFiles.vbs
' // Author:	Michael Petersen, Coretech A/S. info@coretech.dk
' // Purpose:   Copy x number of files and folsders in a source folder to a target location 
' // Usage: 	Place script i source folder, and define what to copy using arguments. (FIRST ARGUMENT MUST BE TARGET FOLDER)
' //
' //			To copy one or more file(s) and Folder(s)located in the source folder sypplpy TARGET and FILE/FOLDER name(s) (remember extensions on files)
' //			- Cscript.exe CopyFiles.vbs "TARGETFOLDER" "FILE1.XXX" "FOLDER1" "FILE2.XXX" "FOLDER2"
' //			
' //			To copy all files and folders located in the source folder only supply TARGET 
' //			 - Cscript.exe CopyFiles.vbs "TARGETFOLDER"
' //
' //
' // CORETECH A/S History:
' // 1.0.0     MIP 17/01/2011  Created initial version.
' // Customer History:
' //
' // ***** End Header *****
' //***************************************************************************

Set oFSO = CreateObject("Scripting.FileSystemObject")

Const OverwriteExisting = True

'Get script location
sScriptLocation = Replace(WScript.ScriptFullName,WScript.ScriptName,"")
sSource = Mid(sScriptLocation,1,Len(sScriptLocation)-1)
WScript.Echo "Source is: " & sSource

'Copy files and folders, or entire source
sArgNumber = WScript.Arguments.Count

If sArgNumber <> 0 Then
	sTargetFolder = WScript.Arguments.Item(0)
	WScript.Echo "Targetfolder is: " & sTargetFolder
	'Make sure the taget is not a file
	If Not (Left(Right(sTargetFolder,4),1)) = "." then 
		'If only TARGET exists ad argument, everything will be copied
		If WScript.Arguments.Count = 1 Then 'If only 
			oFSO.CopyFolder sSource, sTargetFolder, OverwriteExisting	
			oFSO.DeleteFile(sTargetFolder & "\" & WScript.ScriptName)
			WScript.Echo "All files copied to Targetfolder " &  sTargetFolder
		Else  
		'If files and folder arguments exist only these will be copied 
			For i = 1 To sArgNumber -1
			sFileName =  WScript.Arguments.Item(i)
				If oFSO.FileExists(sFileName) Then 
					WScript.Echo "File: " & SFileName & " Copied to: " & sTargetFolder
					oFSO.CopyFile sSource & "\" & sFileName, sTargetFolder & "\" & sFileName, OverwriteExisting
				ElseIf oFSO.FolderExists(sFileName) Then
					WScript.Echo "folder: " & sFileName & " Copied to: " & sTargetFolder
					oFSO.CopyFolder sSource & "\" & sFileName, sTargetFolder& "\" & sFileName, OverwriteExisting
				ElseIf (Left(Right(sFileName,5),1)) = "*" Then
					WScript.Echo "All : " & SFileName & " files Copied to: " & sTargetFolder
					oFSO.CopyFile sSource & "\" & sFileName, sTargetFolder & "\", OverwriteExisting 
				Else
				WScript.Echo "ERROR - " & sFileName & ": does not exist in the source folder!"
				End If			 
			Next
		End If
	Else
		WScript.Echo "ERROR - "	& sTargetFolder & " Is not a valid FolderName. First Argument must be the tagret folder!"
		Wscript.Quit(1)
	End If				
Else 
	WScript.Echo "ERROR - No Arguments present!"	
	Wscript.Quit(1)
End If	








