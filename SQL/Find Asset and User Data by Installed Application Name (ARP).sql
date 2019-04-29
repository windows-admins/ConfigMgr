
/*

	Purpose: Gather Information about Assets with defined application in Add/Remove Programs

	Author(s): Chris Kibble (www.ChristopherKibble.com)
	Contributor(s): 
	Created: 2019-04-29
	Last Updated: 2019-04-29

	To Use: 
	
		1) Connect to your SCCM database.
		2) Modify the LIKE clause to identify the application as necessary.
		3) Execute.

	Comments:

		* Using condition in JOIN so that not all applications are returned and instead we only join the view when the application exists.  Open to better ways of doing this.
		* Requires that you be collecting Unique_User_Name0, cn0, and Mail0 during Active Directory User discovery or those fields may return errors.

*/


select v_r_system.name0
     , v_add_remove_programs.Publisher0
     , v_add_remove_programs.displayname0
     , v_add_remove_programs.Version0
	 , v_add_remove_programs.installdate0
	 , v_R_User.Unique_User_Name0
	 , v_R_User.cn0
	 , v_R_User.Mail0
  from v_r_system
  join v_add_remove_programs
    on v_r_system.resourceid = v_add_remove_programs.resourceid
   and v_add_remove_programs.displayname0 like 'Microsoft Visio%'
  left join v_gs_system_console_usage
    on v_r_system.resourceid = v_gs_system_console_usage.resourceid
  left join v_r_user
    on v_gs_system_console_usage.topconsoleuser0 = v_r_user.Unique_User_Name0;
