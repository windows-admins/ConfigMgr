
/*

	Purpose: Find Assets by Primary User (Top Console User)

	Author(s): Chris Kibble (www.ChristopherKibble.com)
	Contributor(s): 
	Created: 2019-04-29
	Last Updated: 2019-04-29

	To Use: 
	
		1) Connect to your SCCM database.
		2) Modify the WHERE clause to include the user email address.
		3) Execute.

	Comments:

		* Requires that you be collecting cn0 and Mail0 during Active Directory User discovery or those fields may return errors.

*/


select v_r_system.name0
     , v_r_system.Operating_System_Name_and0
	 , v_R_User.Unique_User_Name0
	 , v_R_User.cn0
	 , v_R_User.Mail0
  from v_r_system
  join v_gs_system_console_usage
    on v_r_system.resourceid = v_gs_system_console_usage.resourceid
  join v_r_user
    on v_gs_system_console_usage.topconsoleuser0 = v_r_user.Unique_User_Name0
 where v_r_user.mail0 = 'christopher.kibble@biogen.com';