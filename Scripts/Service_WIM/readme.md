This script automates a number of the .wim maintenance steps outlined in Dan Padgett's blog here:

https://execmgr.net/2018/06/07/windows-10-image-maintenance/

In summary, it performs the following:

- Exports a single index from a Windows 10 .wim file (Enterprise, Pro, etc.)
- Runs dism to add available updates to the .wim file.
- Runs dism cleanup / resetbase to optimize the .wim file size.
- Exports the final modified .wim to further optimize the file size.