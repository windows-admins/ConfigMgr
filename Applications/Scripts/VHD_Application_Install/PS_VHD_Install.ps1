#Thanks to @jgkps for the installation method and @LtBehr for his version of the PS Script, which this is based upon.

#Folder containing this script. VHD should reside in the root alongside the script.
if(!$PSScriptRoot){$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent}

#VHD Path
$vhd = (Get-ChildItem $PSScriptRoot\*.vhd)

Try{
#Mount VHD and get its Drive Letter for use in the installation command.
#Drive will be writeable by default to allow for installers that write temp files. Add -ReadOnly to Mount-DiskImage if this is not desired.
$Volume_Letter = (Mount-DiskImage $vhd -PassThru | Get-DiskImage | Get-Disk | Get-Partition | Get-Volume).DriveLetter
}Catch{
Exit 1
}

Try{
#Execute your silent install command here. Example of AutoDesk Maya.
Start-Process "$($Volume_Letter):\Img\Setup.exe" -ArgumentList "/qb /I $($Volume_Letter):\Img\Maya2018_Silent.ini /Trial /language en-us" -Wait
}Catch{
#Unmount the VHD if we fail.
Dismount-DiskImage $vhdpath
}

Try{
#Unount the VHD when we are done.
Dismount-DiskImage $vhdpath
}Catch{
Exit 1
}