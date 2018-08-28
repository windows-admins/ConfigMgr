

$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment



$tsenv.Value("Dell_SecureBoot") = ((.\cctk\X86_64\cctk.exe --SecureBoot) -eq 'SecureBoot=Enabled')

$tsenv.Value("Dell_UefiNwStack") = ((.\cctk\X86_64\cctk.exe --UefiNwStack) -eq 'UefiNwStack=Enabled')

$tsenv.Value("Dell_WakeOnLan") = ((.\cctk\X86_64\cctk.exe --WakeOnLan) -eq 'WakeOnLan=LanOnly')

$tsenv.Value("Dell_tpm") = ((.\cctk\X86_64\cctk.exe --tpm) -eq 'TpmSecurity=Enabled')

$tsenv.Value("Dell_tpmactivation") = ((.\cctk\X86_64\cctk.exe --tpmactivation) -eq 'TpmActivation=Enabled')

$tsenv.Value("Dell_Virtualization") = ((.\cctk\X86_64\cctk.exe --Virtualization) -eq 'Virtualization=Enabled')