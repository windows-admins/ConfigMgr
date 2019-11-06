### How to use
1. Download the entire repository. You can do this using the Github Desktop application, or by browsing to the root and clicking on the green `Download` button.
2. Extract the entire repository to a temporary location.
3. Import the desired task sequence.  Note that you will need to point to a UNC path, and to ignore dependencies. (See note below)
4. Edit the task sequence, and fix all missing packages (and paths, if you changed the source file paths).
5. Distribute and deploy.

To import:
1) Copy files to the package source.  Note that the location you copy the files to will be the package source path for the packages used by the task sequence.
2) Import the task sequence.
3) Distribut packages.
4) Deploy and :beer:


- `MBR2GPT` - Task Sequence to convert from MBR2GPT (and BIOS to UEFI).  Can be deployed standalone or as part of OSD.
- `Modular OSD` - Newer version of the master deployment, requires SCCM CB 1710+ with nested task sequences enabled.
  - As soon as these are imported please copy the task sequence, reimporting later will overwrite the task sequence
