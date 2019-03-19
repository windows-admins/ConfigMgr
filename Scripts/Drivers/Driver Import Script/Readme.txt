Driver Import


Requirements:
*Running as user with permissions to connect to the SCCM server and perform necessary tasks (import drivers, create packages, etc)
*Running as user with permissions to create/modify/delete driver files and folders
*Running from system with System Center Configuration Manager Cmdlet Library installed
	-https://technet.microsoft.com/en-us/library/dn958404(v=sc.20)aspx
*PowerShell 3.0 or later installed
*If script signing is required, the scripts were signed with the Code Signing cert. This cert (and the parent cert) must be trusted.
*CM Console is recommended but *NOT* required
*If you are not starting with a clean (empty) driver database, see the caveats below.


Pre-Flight steps:
*Create driver folder structure
	-Folder structure *MUST* adhere to the standard 3 tier structure.
		+\<VENDOR>\<Model>\<OSVersion&Architechture>
		+EXAMPLE: \Microsoft\SurfacePro3\Win10x64\
	-Note: Slight exceptions for WinPE and VM (and other) drivers
		+WinPE drivers go under the manufacturer in a WinPE folder.  The WinPE version and architecture goes under this (for the third tier).
		+Oddball and one-off drivers go under the "Other" folder. Because of this, they are only two layers deep ("Other" counts for the first tier).
		+EXAMPLE: \Other\Dell\DockDriver\
		+If it's something that's versioned and changes, you can add a layer for versioning. (This is actually better than the example above.)
		+EXAMPLE: \DisplayLink\10.0.0.1\Win10x64\
*If a driver package needs to be re-run for any reason, manually delete the *.hash file found in the driver package folder.


Running the script:
*Open command prompt
*Run the command: powershell
*Run the command: \\<SERVER_FQDN>\Source$\OSD\Drivers\_Scripts\ImportDrivers.ps1
*When process is complete, update distribution points as needed


Notes:
*The default variables are hard coded into the script, but can be overridden by passing them in.
	-Most likely the only variable that will need to be changed is to set -VerboseLogging $true

*The script will output a log to the directory in which it's run from.  The log is created in cmtrace format for readability.
	-The script will log a date/time stamp each time it is run.
	-Unless -VerboseLogging is set to $true, the script will only log very high level steps and errors.

*After each driver package is run, a hash file is created. This will cause that driver package to be skipped on future runs, unless the hash file is different than the current hash.
	-Deleting, adding, or modifying files will cause the hash to change.
*Each driver is checked to see if it already exists in the database. In order to be a match, the driver .INF file name and location must match the content source path in Configuration Manager, and the driver must already be in the current driver package that we are processing.  If any of these are not true, the driver will be reimported.
	-This means if someone removes the driver from the category but *NOT* the package, it will not reimport, and this won't be fixed.
*When a driver is imported, we attach it to the current category and driver package.  The driver is enabled and allowed to be installed.  If this is a duplicate driver, we append the new category to any existing ones.  We *DO NOT* update any distribution points.
*Once a driver has been imported, *YOU CANNOT REMOVE OR MOVE THE SOURCE PATH*!!! This will wreak havoc on your driver database. You must remove all references to the driver (by deleting it) from inside the console, then make changes and rerun the import.


Unclean! Unclean driver database!
If you already have drivers in your database, the recommendation is to NUKE THEM ALL.  There is a script provided that will eliminate all drivers, packages, and categories.
The reason for this is that the way that the GUI imports drivers is not the exact same.  Ironically both use PowerShell cmdlets, but the GUI seems to be less aggressive at finding duplicate drivers.
Additionally, the initial driver structure is unlikely to match the structure required by the script.  While you *COULD* leave the old structure in place, newly imported drivers (under the new structure) could be duplicates of drivers under the old structure, so this is...messy.  The "new" driver will point to the old driver, and things get really complex really fast.
Additionally, it's the rare driver database that does not have issues.  Very likely if you're reading this, your driver database has missing, overwritten, moved, or renamed files.  This breaks drivers, and often the effects are not noticed until weeks or months down the road.
So, nuke the database, migrate all the old drivers into the new three tiered driver structure, and reimport it all via the script.  Even for very large databases this entire process shouldn't take more than 1-2 days.  In the end you will have something very clean, and avoid a lot of common issues.
