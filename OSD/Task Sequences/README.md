`ModularOSD.zip` - Newer version of the master deployment, requires SCCM CB 1710+ with nested task sequences enabled.

TeslaSysA [10:05]
As soon as they are imported, copy them immediately.
If you reimport a new version, it will overwrite what you have.
Copy and work off the copy.
I would go so far as suggesting you actually manually create new ones.
Due to the 1709 bugs with Child TSes.

------ Older version 
`Win 10 1607.zip` - Legacy OSD TS designed to be used with a B&C image (not recommended).

`Win10MasterDeployment.zip` - Single TS designed to deploy using a vanilla image.

