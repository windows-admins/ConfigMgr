For installations with thousands of files, it's more efficient to transfer one large VHD. This script will mount the VHD, run the installation, then unmount the VHD.

To create a VHD:

1. Run Computer Management and select the Disk Management node.
2. Select Action -> Create VHD
3. Browse to the Save Location.
4. Set the VHD Size.
5. Use VHD for backward compatibility. (The included script assumes .VHD files, so adjust accordingly).
6. Fixed vs. Dynamic is up to you.
7. Once created, the VHD will attach in the Disk Management window.
8. Right click its row header(the "Disk 3, Unknown, Not Initialized" box) and select "Initialize Disk". MBR is fine unless you have a specific need for GPT.
9. Right click the unallocated space and create / format a new Volume.
10. In Windows Explorer, copy your installation source files to the mounted VHD.
11. Right click and "Eject" when finished.

To Use:

1. Modify PS_VHD_Install.ps1 with your installation command line.
2. Include the VHD and the PS_VHD_Install.ps1 script in the root of your application source.
3. Create your application in SCCM as normal and run PS_VHD_Install.ps1 as your installation program. 