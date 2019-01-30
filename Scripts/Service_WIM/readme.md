This script automates a number of the .wim maintenance steps outlined in Dan Padgett's blog here:

https://execmgr.net/2018/06/07/windows-10-image-maintenance/

In summary, it performs the following:

- Exports a single index from a Windows 10 .wim file (Enterprise, Pro, etc.)
- Runs dism to add available updates to the .wim file.
- Runs dism cleanup / resetbase to optimize the .wim file size.
- Exports the final modified .wim to further optimize the file size.

## Usage

Place all update files (.cab or .msu) you'd like serviced into the .wim file in the same directory as the .wim.

NOTE: If you are adding updates to the .wim, be sure to include the Servicing Stack Update and prefix the name of the update file with "1-" so that it is added first.

https://support.microsoft.com/en-us/help/4132216/servicing-stack-update-for-windows-10-1607-may-17-2018
https://support.microsoft.com/en-us/help/4132650/servicing-stack-update-for-windows-10-version-1709-may-21-2018
https://support.microsoft.com/en-us/help/4338853/servicing-stack-update-for-windows-10-version-1803-june-26-2018
https://support.microsoft.com/en-gb/help/4456655/servicing-stack-update-for-windows-10-version-1803-september-11-2018

## Examples

Export a single Index, add updates, optimize .wim

```powershell
.\Service_WIM.ps1 -SourceImage "C:\WIM-Source\install.wim" -MountDir "C:\WIM" -DestinationImage "C:\WIM-Source\install-new.wim" -WinVersion "Windows 10 Enterprise"
```

Remove Indexes only

```powershell
.\Service_WIM.ps1 -IndexOnly -SourceImage "C:\WIM-Source\install.wim" -WinVersion "Windows 10 Enterprise" -DestinationImage "C:\WIM-Source\install-new.wim"
```
