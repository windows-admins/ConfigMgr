The Synergistic Extra Modern Method of Total End-to-End Driver Management


Usecase:
This is ideally used in one of two difference scenarios:
1) To stage drivers for an Upgrade in Place (UIP) scenario.  You can use this to download just the drivers required by the OS, either to prestage or directly as part of the UIP task sequence.
2) To update online workstations (keeping drivers up to date).

To Run:
.\AutoApplyDrivers.ps1 -Path "c:\Temp\Drivers\" -SCCMServer cm1.corp.contoso.com -SCCMServerDB "ConfigMgr_CHQ" -Credential (Get-Credential -UserName "CORP\Drivers" -Message "Enter password")

To setup:

Active Directory:
1) Create a domain service account.
(Basic service account security principles apply)

SQL:
1) In SQL Server Management Studio, browse to Security -> Logins
2) Right Click -> New Login
3) Add the domain service account created above.
4) Select User Mapping
5) Check the box under Map for the ConfigMgr_ database
6) In the Database role membership, check the box for db_datareader

IIS:
Note: Unsure as to which of these made this work (user group or folder perms).
1) Add the domain service account to the IIS_IUSRS group.
2) In Internet Information Services (IIS) Manager, select the Default Web Site.
   Note: If you created the distribution point under a different site, you will need to select that one.
3) Right click on SMS_DP_SMSPKG$ -> Edit Permission
4) Security -> Edit -> Add
5) Add the domain service account
6) Default permissions should suffice.  Do not check Full Control, Modify, or Write