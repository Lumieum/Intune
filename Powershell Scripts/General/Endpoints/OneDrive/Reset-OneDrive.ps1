<#	
	.DESCRIPTION
		Reset OneDrive - This script will check various locations for the OneDrive service.  If it finds that the service, it will stop it and reset it.
#>

# Capture the various paths to OneDrive
$paths = 'C:\Program Files\Microsoft OneDrive\onedrive.exe', 'C:\Program Files (x86)\Microsoft OneDrive\onedrive.exe', '%localappdata%\Microsoft\OneDrive\onedrive.exe'

# Loop through the paths and reset the service for that path
foreach ($path in $paths)
{
	$onedriveexe = test-path $path
	if ($onedriveexe -eq $true)
	{
		Try
		{
			write-host $path 'found.'
			Stop-Process -Name OneDrive -Force
			Remove-Item -Path "$env:USERPROFILE\AppData\Local\Microsoft\OneDrive" -Recurse -Force
			Start-Process $path
		}
		Catch
		{
			write-host "An error occurred: $($_.Exception.Message)"
		}
	}
	else
	{
		write-host 'No' $path 'found.'
	}
	
}
exit $LASTEXITCODE