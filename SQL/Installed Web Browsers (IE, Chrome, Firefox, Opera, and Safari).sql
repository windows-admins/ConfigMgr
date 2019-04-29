
/*

	Purpose: Find Assets by Primary User (Top Console User)

	Author(s): Chris Kibble (www.ChristopherKibble.com)
	Contributor(s): 
	Created: 2019-04-29
	Last Updated: 2019-04-29

	To Use: 
	
		1) Connect to your SCCM database.
		2) Execute.

	Comments:

		* This gets kludge at times, but has served me well and uses a lot of wildcards to find all possible variations of a browser.  Open to suggestions.
		* May return errors if you're not capturing Full_User_Name0 or Mail0 in your Active Directory User Discovery, these can be removed as required.

*/



/* Find Firefox, Chrome (System), Opera, and Safari */
select distinct v_R_System.Name0
     , v_add_remove_programs.Publisher0
	 , v_add_remove_programs.displayname0
	 , case when charindex('Firefox', v_add_remove_programs.displayname0) > 0 then 'Mozilla Firefox'
	        when charindex('Chrome', v_add_remove_programs.displayname0) > 0 then 'Google Chrome'
			when charindex('Opera', v_add_remove_programs.displayname0) > 0 then 'Opera'
			when charindex('Safari', v_add_remove_programs.displayname0) > 0 then 'Apple Safari'
		    else v_add_remove_programs.displayname0
	   end BrowserTitle
     , v_add_remove_programs.Version0
     , case when charindex('.',v_add_remove_programs.version0) > 0 then substring(v_add_remove_programs.version0, 1, charindex('.',v_add_remove_programs.version0)-1)
	   else v_add_remove_programs.version0
	   end version_major
	 , v_r_user.Full_User_Name0
	 , v_r_user.Mail0
  from v_R_System
  join v_Add_Remove_Programs
    on v_R_System.ResourceID = v_Add_Remove_Programs.ResourceID
  left join v_GS_SYSTEM_CONSOLE_USAGE
    on v_r_system.resourceid = v_GS_SYSTEM_CONSOLE_USAGE.ResourceID
  left join v_R_User
    on v_r_user.Unique_User_Name0 = v_GS_SYSTEM_CONSOLE_USAGE.TopConsoleUser0
 where (v_add_remove_programs.displayname0 like '%Firefox%' and v_Add_Remove_Programs.Publisher0 like '%Mozilla%')
 	or (v_add_remove_programs.displayname0 like '%Safari%' and v_Add_Remove_Programs.Publisher0 like '%Apple%')
	or (v_add_remove_programs.displayname0 like '%Opera%' and v_Add_Remove_Programs.Publisher0 like '%Opera%')
	or v_add_remove_programs.displayname0 = 'Google Chrome'

 union all 

/* Union IE Users by File Name */
select distinct v_R_System.Name0
     , 'Microsoft' as Publisher0
	 , 'Internet Explorer' as Displayname0
	 , 'Internet Explorer' as BrowserTitle
     , v_GS_SoftwareFile.FileVersion as Version0
     , case when charindex('.',v_GS_SoftwareFile.FileVersion) > 0 then substring(v_GS_SoftwareFile.FileVersion, 1, charindex('.',v_GS_SoftwareFile.FileVersion)-1)
	   else v_GS_SoftwareFile.FileVersion
	   end version_major
	 , v_r_user.Full_User_Name0
	 , v_r_user.Mail0
  from v_R_System
  join v_GS_SoftwareFile
    on v_GS_SoftwareFile.ResourceID = v_R_System.ResourceID
  join v_GS_OPERATING_SYSTEM
    on v_GS_OPERATING_SYSTEM.ResourceID = v_R_System.ResourceID
  join v_GS_WORKSTATION_STATUS
    on v_GS_WORKSTATION_STATUS.ResourceID = v_R_System.ResourceID
  left join v_GS_SYSTEM_CONSOLE_USAGE
    on v_r_system.resourceid = v_GS_SYSTEM_CONSOLE_USAGE.ResourceID
  left join v_R_User
    on v_r_user.Unique_User_Name0 = v_GS_SYSTEM_CONSOLE_USAGE.TopConsoleUser0
 where v_GS_SoftwareFile.FileName = 'iexplore.exe'
   and v_GS_SoftwareFile.FilePath like '%:\Program Files%\Internet Explorer%'
   and v_GS_SoftwareFile.FilePath not like '%Recycle%'

union all

/* Union Google (User) */
select distinct v_R_System.Name0
     , 'Google' as Publisher0
	 , 'Google Chrome' as Displayname0
	 , 'Google Chrome' as BrowserTitle
     , v_GS_SoftwareFile.FileVersion as Version0
     , case when charindex('.',v_GS_SoftwareFile.FileVersion) > 0 then substring(v_GS_SoftwareFile.FileVersion, 1, charindex('.',v_GS_SoftwareFile.FileVersion)-1)
	   else v_GS_SoftwareFile.FileVersion
	   end version_major
	 , v_r_user.Full_User_Name0
	 , v_r_user.Mail0
  from v_R_System
  join v_GS_SoftwareFile
    on v_GS_SoftwareFile.ResourceID = v_R_System.ResourceID
  join v_GS_OPERATING_SYSTEM
    on v_GS_OPERATING_SYSTEM.ResourceID = v_R_System.ResourceID
  join v_GS_WORKSTATION_STATUS
    on v_GS_WORKSTATION_STATUS.ResourceID = v_R_System.ResourceID
  left join v_GS_SYSTEM_CONSOLE_USAGE
    on v_r_system.resourceid = v_GS_SYSTEM_CONSOLE_USAGE.ResourceID
  left join v_R_User
    on v_r_user.Unique_User_Name0 = v_GS_SYSTEM_CONSOLE_USAGE.TopConsoleUser0
 where v_GS_SoftwareFile.FileName = 'chrome.exe'
   and v_GS_SoftwareFile.FilePath like '%:\Users\%\AppData\Local\Google\Chrome%'
   and v_GS_SoftwareFile.FilePath not like '%Recycle%'
   and v_GS_SoftwareFile.FilePath not like '%Temporary Internet Files%'
   and v_GS_SoftwareFile.FilePath not like '%Chrome Frame%'
   and v_r_system.ResourceID not in (select ResourceID from v_Add_Remove_Programs where DisplayName0 = 'Google Chrome')
