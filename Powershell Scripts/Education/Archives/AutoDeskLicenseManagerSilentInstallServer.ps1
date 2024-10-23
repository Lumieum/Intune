RUN Write-Host 'Downloading iisnode' ; \  
    $MsiFile = $env:Temp + '\iisnode.msi' ; \
    (New-Object Net.WebClient).DownloadFile('https://download.autodesk.com/us/support/files/network_license_manager/windows/nlm11.18.0.0_ipv4_ipv6_win64.msi', $MsiFile) ; \
    Write-Host 'Installing iisnode' ; \
    Start-Process msiexec.exe -ArgumentList '/i', $MsiFile, '/quiet', '/norestart' -NoNewWindow -Wait