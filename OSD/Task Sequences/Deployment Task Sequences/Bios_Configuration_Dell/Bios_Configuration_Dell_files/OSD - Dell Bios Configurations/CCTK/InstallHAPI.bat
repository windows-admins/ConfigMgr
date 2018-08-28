@echo off

if defined programfiles(x86) (
	call %0%\..\x86_64\HAPI\HAPIInstall.bat
) else (
	call %0%\..\x86\HAPI\HAPIInstall.bat
)	


