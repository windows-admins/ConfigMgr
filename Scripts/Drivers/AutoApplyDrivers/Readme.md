# Integral Design of Just In Time Modern Driver Management

### Use case:
This is ideally used in one of two difference scenarios:
1) To stage drivers for an Upgrade in Place (UIP) scenario.  You can use this to download just the drivers required by the OS, either to prestage or directly as part of the UIP task sequence.
2) To update online workstations (keeping drivers up to date).

### To Run:
.\AutoApplyDrivers.ps1 -Path "c:\Temp\Drivers\" -SCCMServer cm1.corp.contoso.com -SCCMServerDB "ConfigMgr_CHQ" -Credential (Get-Credential -UserName "CORP\Drivers" -Message "Enter password")

## Requirements
#### What *IS* required:
1) SCCM
2) Driver database populated with drivers

#### What is *NOT* required:
1) New creation of driver packages
2) Web services
3) Expensive consulting engagements (unless you want to...) 

## To setup
#### SCCM
1) Create a package for the PoSh files.
2) Import the example task sequence.
3) Fix references in the task sequence.
4) Use inside a UIP TS or stand alone.

#### Active Directory:
1) Create a domain service account.
(Basic service account security principles apply)

#### SQL:
1) In SQL Server Management Studio, browse to Security -> Logins
2) Right Click -> New Login
3) Add the domain service account created above.
4) Select User Mapping
5) Check the box under Map for the ConfigMgr_ database
6) In the Database role membership, check the box for db_datareader
7) Execute the following command (change the domain\account name): `GRANT EXECUTE ON dbo.MP_MatchDrivers TO [CORP\Drivers];`

#### IIS:
Note: Unsure as to which of these made this work (user group or folder perms).
1) Add the domain service account to the IIS_IUSRS group.
2) In Internet Information Services (IIS) Manager, select the Default Web Site.
   Note: If you created the distribution point under a different site, you will need to select that one.
3) Right click on SMS_DP_SMSPKG$ -> Edit Permission
4) Security -> Edit -> Add
5) Add the domain service account
6) Default permissions should suffice.  Do not check Full Control, Modify, or Write



## Potential Gotchas
1) If the context the script executes under has no local administrator access, the script will be unable to compare the drivers found in SCCM to the local drivers, and will not be able to identify which drivers are newer.  Thus all possible matching drivers will be downloaded.
2) If the context the script executes under has no local administrator access, the script will be unable to install drivers and installation must be handled outside of the script execution.
3) For an Upgrade in Place (UIP/IPU) scenario it's recommended you set the following to `$False`.  If either is set to `$True` you have a much higher likelyhood of missing important/critical drivers as part of the upgrade.
```
[bool]$HardwareMustBePresent = $False,
[bool]$UpdateOnlyDatedDrivers = $False,
```
