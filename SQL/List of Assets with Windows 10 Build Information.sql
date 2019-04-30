
/*

	Purpose: Maps Windows 10 Build Numbers to Version and gathers data on all assets running Windows 10.

	Author(s): Chris Kibble (www.ChristopherKibble.com)
	Contributor(s): 
	Created: 2019-04-30
	Last Updated: 2019-04-30

	To Use: 
	
		1) Connect to your SCCM database.
		2) Execute.

	Comments:

		* https://en.wikipedia.org/wiki/Windows_10_version_history (Build Number Source)
		* Requires that you be collecting Full_User_Name0 and Mail0 during Active Directory User discovery or those fields may return errors.

*/

-- 

select v_r_system.name0
     , v_GS_OPERATING_SYSTEM.Caption0
	 , v_GS_OPERATING_SYSTEM.BuildNumber0
	 , case when v_GS_OPERATING_SYSTEM.BuildNumber0 = '10240' then '1507'
	        when v_GS_OPERATING_SYSTEM.BuildNumber0 = '10586' then '1511'
			when v_GS_OPERATING_SYSTEM.BuildNumber0 = '14393' then '1607'
			when v_GS_OPERATING_SYSTEM.BuildNumber0 = '15063' then '1703'
			when v_GS_OPERATING_SYSTEM.BuildNumber0 = '16299' then '1709'
			when v_GS_OPERATING_SYSTEM.BuildNumber0 = '17134' then '1803'
			when v_GS_OPERATING_SYSTEM.BuildNumber0 = '17763' then '1809'
			when v_GS_OPERATING_SYSTEM.BuildNumber0 = '18362' then '1903'
			else '????'
	   end as Win10Version
	 , v_R_User.Full_User_Name0
	 , v_r_user.Mail0
  from v_r_system
  join v_gs_operating_system
    on v_r_system.ResourceID = v_gs_operating_system.ResourceID
  left join v_GS_SYSTEM_CONSOLE_USAGE
    on v_r_system.ResourceID = v_GS_SYSTEM_CONSOLE_USAGE.ResourceID
  left join v_R_User
    on v_R_User.Unique_User_Name0 = v_GS_SYSTEM_CONSOLE_USAGE.TopConsoleUser0
 where v_GS_OPERATING_SYSTEM.Caption0 like 'Microsoft Windows 10%'


