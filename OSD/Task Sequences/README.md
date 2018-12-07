- `ModularOSD.zip` - Newer version of the master deployment, requires SCCM CB 1710+ with nested task sequences enabled.
  - As soon as these are imported please copy the task sequence, reimporting later will overwrite the task sequence
  - For now please copy the task sequence steps to a clean TS, there is a bug that causes it not to function because it was created on 1710

------ Older version 
`Win 10 1607.zip` - Legacy OSD TS designed to be used with a B&C image (not recommended).

`Win10MasterDeployment.zip` - Single TS designed to deploy using a vanilla image.

