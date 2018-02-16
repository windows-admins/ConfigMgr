#Removes all indexes from an install.wim file except for specified index.
#Useful if you use SCCM Servicing to inject updates and only use one index in the .wim. Otherwise SCCM services all indexes.

#Update the following in the script for your needs:
# $image_path
# The index name (edition of Windows) in ($img_index.ImageName -ne "Windows 10 Enterprise")

$image_path = "c:\install.wim"
#Get all indexes
$img_indexes = Get-WindowsImage -ImagePath $image_path

#Create loop to remove indexes until we are left with one.
do {
    #Loop through each index and remove the index if not the designated edition.
    foreach ($img_index in $img_indexes) {
        if ($img_index.ImageName -ne "Windows 10 Enterprise") {
        Remove-WindowsImage -ImagePath $image_path -index $img_index.ImageIndex
        #Break out of the for loop, as we need to refresh the index list if we remove one of them.
        break
        }
    }
    #Refresh the index list.
    $img_indexes = Get-WindowsImage -ImagePath $image_path
} until ($img_indexes.Count -eq 1)