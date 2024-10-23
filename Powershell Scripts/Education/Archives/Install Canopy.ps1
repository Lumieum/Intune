$MsiParams = @{
    FilePath = 'msiexec.exe'
    ArgumentList = @(
        '/i "c:\program files\enthought\canopy-2.1.9.win-x86_64-cp27.msi" SETUP_MANAGED_COMMON_INSTALL="C:\Program Files\Enthought" ALLUSERS="1"'
        '/qn'
         )
    Wait = $true
}
Start-Process @MsiParams