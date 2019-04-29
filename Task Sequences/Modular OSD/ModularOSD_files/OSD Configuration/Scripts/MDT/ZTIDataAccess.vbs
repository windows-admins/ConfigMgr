
' // ***************************************************************************
' // 
' // Copyright (c) Microsoft Corporation.  All rights reserved.
' // 
' // Microsoft Deployment Toolkit Solution Accelerator
' //
' // File:      ZTIDataAccess.vbs
' // 
' // Version:   6.3.8443.1000
' // 
' // Purpose:   Common Routines for Database Access
' // 
' // Usage:     
' // 
' // ***************************************************************************

option Explicit


Class Database

	Private sIniFile
	Private sSection
	Private dicSQLData
	Private oConn

	Private Sub Class_Initialize

		Dim sFoundIniFile
		Dim iRetVal


		' Create a dictionary object to hold the SQL info and initialize it

		Set dicSQLData = CreateObject("Scripting.Dictionary")
		dicSQLData.CompareMode = TextCompare

		dicSQLData("Order") = Array()
		dicSQLData("Parameters") = Array()

		Set oConn = Nothing

	End Sub


	Public Property Let IniFile(sIni)

		Dim sFoundIniFile
		Dim iRetVal


		' Figure out where the CustomSettings.ini file is

		sIniFile = sIni
		If Len(sIniFile) = 0 then
			iRetVal = oUtility.FindFile("CustomSettings.ini", sIniFile)
			If iRetVal <> Success then
				oLogging.CreateEntry "Unable to find CustomSettings.ini, rc = " & iRetVal, LogTypeError
				Exit Property
			End If
			oLogging.CreateEntry "Using DEFAULT VALUE: Ini file = " & sIniFile, LogTypeInfo
		Else
			If not oFSO.FileExists(sIniFile) then
				iRetVal = oUtility.FindFile(sIniFile, sFoundIniFile)
				If iRetVal = Success then
					sIniFile = sFoundIniFile
				End If
			End If
			oLogging.CreateEntry "Using specified INI file = " & sIniFile, LogTypeInfo
		End If

		If Not oFSO.FileExists(sIniFile) then
			oLogging.CreateEntry "Specified INI file does not exist (" & sIniFile & ").", LogTypeError
			Exit Property
		End If

	End Property


	Public Property Let SectionName(sSect)

		Dim iRetVal, re, sElement
		Dim arrSQLDataKeys, sTmpVal
		Dim arrParameters

		iRetVal = Failure
		Set re = new regexp
		re.IgnoreCase = True
		re.Global = True



		' Substitute for any variables in the section name

		sSection = oEnvironment.Substitute(sSect)
		oLogging.CreateEntry "CHECKING the [" & sSection & "] section", LogTypeInfo


		' Get the "normal" values

		dicSQLData("Table") = ""
		dicSQLData("StoredProcedure") = ""
		arrSQLDataKeys = Array("SQLServer", "Instance", "Port", "Database", "Netlib", "Table", "StoredProcedure", "DBID", "DBPwd", "SQLShare", "ParameterCondition")
		for each sElement in arrSQLDataKeys
			sTmpVal = oUtility.ReadIni(sIniFile, sSection, sElement)
			if Len(sTmpVal) = 0 then
				oLogging.CreateEntry sElement & " key not defined in the section [" & sSection & "]", LogTypeInfo
			else
				dicSQLData(sElement) = oEnvironment.Substitute(sTmpVal)
				if Instr(UCase(sElement),"PWD") > 0 then
					oLogging.CreateEntry "Using from [" & sSection & "]: " & sElement & " = ********", LogTypeInfo
				else
					oLogging.CreateEntry "Using from [" & sSection & "]: " & sElement & " = " & sTmpVal, LogTypeInfo
				end if
			end if
		next


		' Handle "Parameters" differently

		sTmpVal = oUtility.ReadIni(sIniFile, sSection, "Parameters")
		If Len(sTmpVal) = 0 then
			oLogging.CreateEntry "No parameters to include in the SQL call were specified", LogTypeInfo
			arrParameters = Array()
		Else
			arrParameters = Split(sTmpVal, ",")
		End If
		dicSQLData("Parameters") = arrParameters


		' Handle "Order" differently

		sTmpVal = oUtility.ReadIni(sIniFile, sSection, "Order")
		If Len(sTmpVal) = 0 then
			arrParameters = Array()
		Else
			arrParameters = Split(sTmpVal, ",")
		End If
		dicSQLData("Order") = arrParameters


		' Make sure required values were specified

		If Len(dicSQLData("SQLServer")) = 0 then
			oLogging.CreateEntry "ERROR - SQLServer NOT defined in the section [" & sSection & "]", LogTypeError
			Exit Property
		End If

		If Len(dicSQLData("Database")) = 0 then
			oLogging.CreateEntry "Database not defined in the section [" & sSection & "]. Using default (BDDAdminDB).", LogTypeInfo
			dicSQLData("Database") = "BDDAdminDB"
		End If
		If Len(dicSQLData("Table")) = 0 and Len(dicSQLData("StoredProcedure")) = 0 then
			oLogging.CreateEntry "Warning - Neither Table or StoredProcedure defined in the section [" & sSection & "]. Using default Table = BDDAdminCore", LogTypeWarning
			dicSQLData("Table") = "BDDAdminCore"
		End If
		If Len(dicSQLData("Netlib")) = 0 then
			oLogging.CreateEntry "Default Netlib of DBNMPNTW (named pipes) will be used for connecting to SQL Server.", LogTypeInfo
			dicSQLData("Netlib") = "DBNMPNTW"
		End If
		If Len(dicSQLData("ParameterCondition")) = 0 then
			oLogging.CreateEntry "Default ParameterCondition 'AND' will be used for building queries with multiple parameters.", LogTypeInfo
			dicSQLData("ParameterCondition") = "AND"
		End If
		If Len(dicSQLData("SQLShare")) = 0 and UCase(dicSQLData("Netlib")) = "DBNMPNTW" then
			oLogging.CreateEntry "SQLShare NOT defined in the section [" & sSection & "], trusted connection may fail if there is not already a connection to the SQL Server.", LogTypeInfo
		End If



		' Was an instance name specified with the SQLServer name?  If so, split them apart

		If Instr(dicSQLData("SQLServer"), "\") > 0 then
			dicSQLData("Instance") = Mid(dicSQLData("SQLServer"), Instr(dicSQLData("SQLServer"), "\") + 1)
			dicSQLData("SQLServer") = Left(dicSQLData("SQLServer"), Instr(dicSQLData("SQLServer"), "\") - 1)
		End If

	End Property


	' SQLServer property

	Public Property Get SQLServer
		If dicSQLData.Exists("SQLServer") then
			SQLServer = dicSQLData("SQLServer")
		Else
			SQLServer = ""
		End if
	End Property

	Public Property Let SQLServer(sSQLServer)
		dicSQLData("SQLServer") = sSQLServer
	End Property


	' Instace property

	Public Property Get Instance
		If dicSQLData.Exists("Instance") then
			Instance = dicSQLData("Instance")
		Else
			Instance = ""
		End if
	End Property

	Public Property Let Instance(sInstance)
		dicSQLData("Instance") = sInstance
	End Property


	' Port property

	Public Property Get Port
		If dicSQLData.Exists("Port") then
			Port = dicSQLData("Port")
		Else
			Port = ""
		End if
	End Property

	Public Property Let Port(sPort)
		dicSQLData("Port") = sPort
	End Property


	' Database property

	Public Property Get Database
		If dicSQLData.Exists("Database") then
			Database = dicSQLData("Database")
		Else
			Database = ""
		End if
	End Property

	Public Property Let Database(sDatabase)
		dicSQLData("Database") = sDatabase
	End Property


	' Netlib property

	Public Property Get Netlib
		If dicSQLData.Exists("Netlib") then
			Netlib = dicSQLData("Netlib")
		Else
			Netlib = ""
		End if
	End Property

	Public Property Let Netlib(sNetlib)
		dicSQLData("Netlib") = sNetlib
	End Property


	' Table property

	Public Property Get Table
		If dicSQLData.Exists("Table") then
			Table = dicSQLData("Table")
		Else
			Table = ""
		End if
	End Property

	Public Property Let Table(sTable)
		dicSQLData("Table") = sTable
	End Property


	' StoredProcedure property

	Public Property Get StoredProcedure
		If dicSQLData.Exists("StoredProcedure") then
			StoredProcedure = dicSQLData("StoredProcedure")
		Else
			StoredProcedure = ""
		End if
	End Property

	Public Property Let StoredProcedure(sStoredProcedure)
		dicSQLData("StoredProcedure") = sStoredProcedure
	End Property


	' DBID property

	Public Property Get DBID
		If dicSQLData.Exists("DBID") then
			DBID = dicSQLData("DBID")
		Else
			DBID = ""
		End if
	End Property

	Public Property Let DBID(sDBID)
		dicSQLData("DBID") = sDBID
	End Property


	' DBPwd property

	Public Property Get DBPwd
		If dicSQLData.Exists("DBPwd") then
			DBPwd = dicSQLData("DBPwd")
		Else
			DBPwd = ""
		End if
	End Property

	Public Property Let DBPwd(sDBPwd)
		dicSQLData("DBPwd") = sDBPwd
	End Property


	' SQLShare property

	Public Property Get SQLShare
		If dicSQLData.Exists("SQLShare") then
			SQLShare = dicSQLData("SQLShare")
		Else
			SQLShare = ""
		End if
	End Property

	Public Property Let SQLShare(sSQLShare)
		dicSQLData("SQLShare") = sSQLShare
	End Property


	' ParameterCondition property

	Public Property Get ParameterCondition
		If dicSQLData.Exists("ParameterCondition") then
			ParameterCondition = dicSQLData("ParameterCondition")
		Else
			ParameterCondition = ""
		End if
	End Property

	Public Property Let ParameterCondition(sParameterCondition)
		dicSQLData("ParameterCondition") = sParameterCondition
	End Property


	' Parameters property

	Public Property Get Parameters
		If dicSQLData.Exists("Parameters") then
			Parameters = Join(dicSQLData("Parameters"), ",")
		Else
			Parameters = ""
		End if
	End Property

	Public Property Let Parameters(sParameters)
		If sParameters = "" then
			dicSQLData("Parameters") = Array()
		Else
			dicSQLData("Parameters") = Split(sParameters, ",")
		End if
	End Property


	' Order property

	Public Property Get Order 
		If dicSQLData.Exists("Order") then
			Order = Join(dicSQLData("Order"), ",")
		Else
			Order = ""
		End if
	End Property

	Public Property Let Order(sOrder)
		If sOrder = "" then
			dicSQLData("Order") = Array()
		Else
			dicSQLData("Order") = Split(sOrder, ",")
		End if
	End Property


	Public Function Connect

		Dim sDSNRef
		Dim sMsg


		' Create a new ADO connection object

		On Error Resume Next
		Set oConn = CreateObject("ADODB.Connection")
		If Err then
			oLogging.CreateEntry "ERROR - Unable to create ADODB.Connection object, impossible to query SQL Server: " & Err.Description & " (" & Err.Number & ")", LogTypeError
			Set Connect = Nothing
			Exit Function
		End If
		On Error Goto 0


		' If a SQLShare value is specified, try to establish a connection

		If Len(dicSQLData("DBID")) = 0 or Len(dicSQLData("DBPwd")) = 0 then
			If Len(dicSQLData("SQLShare")) > 0 then
				oUtility.ValidateConnection "\\" & dicSQLData("SQLServer") & "\" & dicSQLData("SQLShare")
			Else
				oLogging.CreateEntry "No SQLShare value was specified, not possible to establish a secure connection.", LogTypeInfo
			End If
		End If


		' Build the connect string

		sDSNRef = "Provider=SQLOLEDB;OLE DB Services=0;Data Source=" & dicSQLData("SQLServer")

		If Len(dicSQLData("Instance")) > 0 then
			sDSNRef = sDSNRef & "\" & dicSQLData("Instance")
		End If
		If Len(dicSQLData("Port")) > 0 then
			sDSNRef = sDSNRef & "," & dicSQLData("Port")
		End If

		sDSNRef = sDSNRef & ";Initial Catalog=" & dicSQLData("Database") & ";Network Library=" & dicSQLData("Netlib")

		If len(dicSQLData("DBID")) = 0 OR len(dicSQLData("DBPwd")) = 0 then
			oLogging.CreateEntry "OPENING TRUSTED SQL CONNECTION to server " & dicSQLData("SQLServer") & ".", LogTypeInfo
			sDSNRef = sDSNRef & ";Integrated Security=SSPI"
		Else
			oLogging.CreateEntry "OPENING STANDARD SECURITY SQL CONNECTION to server " & dicSQLData("SQLServer") & " using login " & dicSQLData("DBID") & ".", LogTypeInfo
			sDSNRef = sDSNRef & ";User ID=" & dicSQLData("DBID") & ";Password=" & dicSQLData("DBPwd")
		End If


		' Connect to the database

		oLogging.CreateEntry "Connecting to SQL Server using connect string: " & sDSNref, LogTypeInfo
		On Error Resume Next
		oConn.Open sDSNref
		If Err then
			sMsg = Err.Description & " (" & Err.Number & ")"

			CreateEvent 41013, LogTypeError, "ZTI error opening SQL connection: " & sMsg

			iRetVal = Failure
			oLogging.CreateEntry "ZTI error opening SQL Connection: " & sMsg, LogTypeError
			For each objErr in oConn.Errors
				oLogging.CreateEntry "  ADO error: " & objErr.Description & " (Error #" & objErr.Number & "; Source: " & objErr.Source & "; SQL State: " & objErr.SQLState & "; NativeError: " & objErr.NativeError & ")", LogTypeError
			Next
			Err.Clear
			Set Connect = Nothing
			Exit Function
		End If
		On Error Goto 0

		oLogging.CreateEntry "Successfully opened connection to database.", LogTypeInfo



		' Return the connection to the caller

		Set Connect = oConn

	End Function


	Public Property Get Connection

		Set Connection = oConn

	End Property


	Public Function Query

		Dim oRS
		Dim sErrMsg, sSelect, sElement, sColumn, objTmp, bFoundColumn, bFirst
		Dim tmpValue, tmpArray, tmpClause, v, bClauseFirst, objErr
		Dim sMsg
		Dim bValueFound


		' Create ADO recordset object

		On Error Resume Next
		Set oRS = CreateObject("ADODB.Recordset")
		If Err then
			Set Query = Nothing
			oLogging.CreateEntry "ERROR - Unable to create ADODB.Recordset object, impossible to query SQL Server: " & Err.Description & " (" & Err.Number & ")", LogTypeError
			Exit Function
		End If
		On Error Goto 0


		' Build the SQL statement

		If dicSQLData("Table") <> "" then


			sSelect = "SELECT * FROM " & dicSQLData("Table") & " WHERE "
			bFirst = True
			For each sElement in dicSQLData("Parameters")

				sElement = UCase(trim(sElement))

				' Find the column ID to use

				sColumn = TranslateToColumnID(sElement)


				' Find the value to work with

				bValueFound = False
				If oEnvironment.ListItem(sElement).Count > 0 then
					Set tmpValue = oEnvironment.ListItem(sElement)
					For each v in tmpValue.Keys
						If v <> "" then
							bValueFound = true
							Exit For
						End If
					Next
				ElseIf oEnvironment.Item(sElement) <> "" then
					tmpValue = oEnvironment.Item(sElement)
					bValueFound = true
				Else
					tmpValue = ""
				End If

				If bValueFound then

					' Check if an AND/OR is needed

					If not bFirst then
						sSelect = sSelect & " " & dicSQLData("ParameterCondition") & " "
					Else
						bFirst = False
					End If


					' Handle it appropriately

					If IsObject(tmpValue) then  ' It must be a dictionary object
						tmpClause = sColumn & " IN ("
						bClauseFirst = True
						For each v in tmpValue.Keys
							If not bClauseFirst then
								tmpClause = tmpClause & ","
							Else
								bClauseFirst = False
							End If
							tmpClause = tmpClause & "'" & v & "'"
						Next
						sSelect = sSelect & tmpClause & ")"
					Else
						sSelect = sSelect & sColumn & " = '" & tmpValue & "'"

					End If

				End If

			Next

			If bFirst then

				oLogging.CreateEntry "No parameters had non-blank values, adding dummy query clause to force no records.", LogTypeInfo
				sSelect = sSelect & "0=1"

			End If


			' See if we need to sort the results

			If UBound(dicSQLData("Order")) >= 0 then

				sSelect = sSelect & " ORDER BY "

				For each sElement in dicSQLData("Order")

					sElement = Trim(sElement)


					' Find the column ID to use

					sColumn = TranslateToColumnID(sElement)


					' Add the clause

					sSelect = sSelect & sColumn & ", "

				Next


				' Trim the last comma/space

				sSelect = Left(sSelect, Len(sSelect)-2)

			End If

		Else

			' Stored procedure to be added

			sSelect = "EXECUTE " & dicSQLData("StoredProcedure") & " "
			bFirst = True
			For each sElement in dicSQLData("Parameters")

				sElement = UCase(trim(sElement))

				' Find the value to work with

				If oEnvironment.ListItem(sElement).Count > 0 then
					Set tmpValue = oEnvironment.ListItem(sElement)
				ElseIf oEnvironment.Item(sElement) <> "" then
					tmpValue = oEnvironment.Item(sElement)
				Else
					oLogging.CreateEntry "No value specified for parameter '" & sElement & "', stored procedure may return no records.", LogTypeInfo
					tmpValue = ""
				End If


				' Check if an AND is needed

				If not bFirst then
					sSelect = sSelect & ", "
				Else
					bFirst = False
				End If


				' Handle it appropriately

				If IsObject(tmpValue) then
					oLogging.CreateEntry "Only the first " & sElement & " value will be used in the stored procedure call.", LogTypeInfo
					tmpArray = tmpValue.Keys
					sSelect = sSelect & "'" & tmpArray(0) & "'"
				Else
					sSelect = sSelect & "'" & tmpValue & "'"
				End If

			Next

		End If


		' Issue the SQL statement

		oLogging.CreateEntry "About to issue SQL statement: " & sSelect, LogTypeInfo
		On Error Resume Next
		oRS.Open sSelect, oConn, adOpenStatic, adLockReadOnly
		If Err then
			Set Query = Nothing
			oLogging.CreateEntry "ERROR - Opening Record Set (Error Number = " & Err.Number & ") (Error Description: " & Err.Description & ").", LogTypeError
			For each objErr in oConn.Errors
				oLogging.CreateEntry "  ADO error: " & objErr.Description & " (Error #" & objErr.Number & "; Source: " & objErr.Source & "; SQL State: " & objErr.SQLState & "; NativeError: " & objErr.NativeError & ")", LogTypeError
			Next
			oRS.Close
			Err.Clear
			Exit Function
		End If
		On Error Goto 0

		oLogging.CreateEntry "Successfully queried the database.", LogTypeInfo

		Set Query = oRS

	End Function

	Public Function TranslateToColumnID(sElement)

		Dim sColumn

		sColumn = oUtility.ReadIni(sIniFile, sSection, sElement)
		If sColumn = "" then
			sColumn = sElement
		End If

		TranslateToColumnID = sColumn

	End Function

End Class


Class WebService

	Private sIniFile
	Private sSection
	Private sURL
	Private sMethod
	Private arrParameters
	Private bQuiet

	Private Sub Class_Initialize

		' Initialize variables

		arrParameters = Array()
		sMethod = "POST"

	End Sub


	Public Property Let IniFile(sIni)

		Dim sFoundIniFile
		Dim iRetVal


		' Figure out where the CustomSettings.ini file is

		sIniFile = sIni
		If Len(sIniFile) = 0 then
			iRetVal = oUtility.FindFile("CustomSettings.ini", sIniFile)
			If iRetVal <> Success then
				oLogging.CreateEntry "Unable to find CustomSettings.ini, rc = " & iRetVal, LogTypeError
				Exit Property
			End If
			oLogging.CreateEntry "Using DEFAULT VALUE: Ini file = " & sIniFile, LogTypeInfo
		Else
			If not oFSO.FileExists(sIniFile) then
				iRetVal = oUtility.FindFile(sIniFile, sFoundIniFile)
				If iRetVal = Success then
					sIniFile = sFoundIniFile
				End If
			End If
			oLogging.CreateEntry "Using specified INI file = " & sIniFile, LogTypeInfo
		End If

		If Not oFSO.FileExists(sIniFile) then
			oLogging.CreateEntry "Specified INI file does not exist (" & sIniFile & ").", LogTypeError
			Exit Property
		End If

	End Property


	Public Property Let SectionName(sSect)

		Dim sTmpVal



		' Substitute for any variables in the section name

		sSection = oEnvironment.Substitute(sSect)
		oLogging.CreateEntry "CHECKING the [" & sSection & "] section", LogTypeInfo


		' Get the URL

		sURL = oUtility.ReadIni(sIniFile, sSection, "WebService")


		' Get "Parameters"

		sTmpVal = oUtility.ReadIni(sIniFile, sSection, "Parameters")
		If Len(sTmpVal) = 0 then
			oLogging.CreateEntry "No parameters to include in the web service call were specified", LogTypeInfo
			arrParameters = Array()
		Else
			arrParameters = Split(sTmpVal, ",")
		End If

		' Get the Method

		sTmpVal = oUtility.ReadIni(sIniFile, sSection, "Method")
		If Len(sTmpVal) <> 0 then
			sMethod = sTmpVal
		End if


	End Property


	' WebService property

	Public Property Get WebService
		WebService = sURL
	End Property

	Public Property Let WebService(sWebService)
		sURL = sWebService
	End Property


	' Parameters property

	Public Property Get Parameters
		Parameters = Join(arrParameters, ",")
	End Property

	Public Property Let Parameters(sParameters)
		If sParameters = "" then
			arrParameters = Array()
		Else
			arrParameters = Split(sParameters, ",")
		End if
	End Property


	' Method property

	Public Property Get Method
		Method = sMethod
	End Property

	Public Property Let Method(sVal)
		sMethod = UCase(sVal)
	End Property


	' Quiet property

	Public Property Get Quiet
		Quiet = bQuiet
	End Property

	Public Property Let Quiet(bVal)
		bQuiet = bVal
	End Property

	Public Function Query

		Dim oHTTP
		Dim sEnvelope
		Dim sReturn
		Dim oReturn
		Dim oNode
		Dim sElement, sColumn
		Dim tmpValue, tmpArray
		Dim sUserID, sPassword
		Dim iSeverity


		Set oHTTP = CreateObject("MSXML2.ServerXMLHTTP")
		Set oReturn = oUtility.GetMSXMLDOMDocument
		oReturn.setProperty "SelectionLanguage", "XPath"
		If sMethod = "REST" then
			oReturn.setProperty "SelectionNamespaces", "xmlns:d='http://schemas.microsoft.com/ado/2007/08/dataservices'"
		End if
		Set Query = oReturn


		If bQuiet then
			iSeverity = LogTypeInfo
		Else
			iSeverity = LogTypeError
		End if


		' Set timeouts to infinite for name resolution, 60 seconds for connect, send, and receive

		oHTTP.setTimeouts 0, 60000, 60000, 60000


		' Ignore SSL errors (avoids having to deal with certificates)

		oHTTP.SetOption 2, 13056


		' Build the envelope

		For each sElement in arrParameters

			sElement = Trim(sElement)


			' Find the column ID to use

			sColumn = TranslateToColumnID(sElement)
			sElement = UCase(sElement)


			' Find the value to work with

			If oEnvironment.ListItem(sElement).Count > 0 then
				Set tmpValue = oEnvironment.ListItem(sElement)
			ElseIf oEnvironment.Item(sElement) <> "" then
				tmpValue = oEnvironment.Item(sElement)
			Else
				oLogging.CreateEntry "No value specified for parameter '" & sElement & "', web service results could be unpredictable.", LogTypeInfo
				tmpValue = ""
			End If


			' Handle it appropriately

			If IsObject(tmpValue) then
				oLogging.CreateEntry "Only the first " & sElement & " value will be used in the web service call.", LogTypeInfo
				tmpArray = tmpValue.Keys
				If UCase(sMethod) = "REST" then
					sEnvelope = sEnvelope & sColumn & " eq '" & tmpArray(0) & "' and "
				Else
					sEnvelope = sEnvelope & sColumn & "=" & tmpArray(0) & "&"
				End if
			Else
				If UCase(sMethod) = "REST" then
					sEnvelope = sEnvelope & sColumn & " eq '" & tmpValue & "' and "
				Else
					sEnvelope = sEnvelope & sColumn & "=" & tmpValue & "&"
				End If
			End If

		Next

		If Len(sEnvelope) > 0 then

			' For REST, remove the final " and ".  Otherwise, just drop the trailing comma.

			If sMethod = "REST" then
				sEnvelope = Left(sEnvelope, Len(sEnvelope) - 5)
			Else
				sEnvelope = Left(sEnvelope, Len(sEnvelope) - 1)
			End if


			' Attach a suffix to the URL for GET and REST requests

			If UCase(sMethod) = "GET" then
				sURL = sURL & "?" & sEnvelope
			ElseIf UCase(sMethod) = "REST" then
				sURL = sURL & "?$filter=" & sEnvelope & ""
			End if

		End If


		' Issue the web service call
		Dim bNAACred
		Dim iTryIteration
		
		iTryIteration = 0
		bNAACred = oUtility.GetNextNAACred(0)
		
		If Not bNAACred Then
			oLogging.CreateEntry "No NAA credentials specified. Using default.", LogTypeVerbose
		Else
			oLogging.CreateEntry "NAA credentials have been specified.", LogTypeVerbose
		End if
				
		Do While (iTryIteration = 0 Or bNAACred)
		
			sUserID = oEnvironment.Item("UserDomain") & "\" & oEnvironment.Item("UserID")
			sPassword = oEnvironment.Item("UserPassword")

			If UCase(sMethod) = "POST" then
				oLogging.CreateEntry "About to execute web service call using method " & sMethod & " to " & sURL & ": " & sEnvelope, LogTypeVerbose
				oHTTP.open "POST", sURL, False, sUserID, sPassword
				oHTTP.setRequestHeader "Content-Type", "application/x-www-form-urlencoded"
				On Error Resume Next
				oHTTP.send sEnvelope
			Else
				oLogging.CreateEntry "About to execute web service call using method " & sMethod & " to " & sURL, LogTypeVerbose
				oHTTP.open "GET", sURL, False, sUserID, sPassword
				On Error Resume Next
				oHTTP.send
			End if
			oLogging.CreateEntry " --Attempt #" & CStr(iTryIteration + 1), LogTypeVerbose

			If Err then
				oLogging.CreateEntry "Error executing web service " & sURL & ": " & Err.Description & " (" & Err.Number & ")", iSeverity
				Set Query = Nothing
				Exit Function
			End If
			On Error Goto 0

			iTryIteration = iTryIteration + 1
			
			If oHTTP.status = 200 then
				oLogging.CreateEntry "Response from web service: " & oHTTP.status & " " & oHTTP.StatusText, LogTypeVerbose
				Exit Do
			ElseIf oHTTP.status = 401 And bNAACred Then
				oLogging.CreateEntry "Web service returned unauthorized: " & oHTTP.status & " " & oHTTP.StatusText & vbCrLf & oHTTP.responseText, LogTypeWarning
				bNAACred = oUtility.GetNextNAACred(iTryIteration)
				If bNAACred Then 
					' We will try another account
					Continue
				Else
					' All accounts have been tried and been denied
					oLogging.CreateEntry "All network access accounts failed to be authorized.", LogTypeError
					Set Invoke = Nothing
					Exit Function
				End If
			Else
				oLogging.CreateEntry "Unexpected response from web service: " &	 oHTTP.status & " " & oHTTP.StatusText & vbCrLf & oHTTP.responseText, iSeverity
				Set Query = Nothing
				Exit Function
			End If
		Loop

		' Process the results

		oReturn.loadXML oHTTP.responseText

		oLogging.CreateEntry "Successfully executed the web service.", LogTypeVerbose

	End Function

	Public Function TranslateToColumnID(sElement)

		Dim sColumn

		sColumn = oUtility.ReadIni(sIniFile, sSection, UCase(sElement))
		If sColumn = "" then
			sColumn = sElement
		End If

		TranslateToColumnID = sColumn

	End Function

End Class
