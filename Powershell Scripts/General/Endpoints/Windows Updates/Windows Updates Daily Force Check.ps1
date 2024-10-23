<#	

	.NOTES

	===========================================================================

	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2021 v5.8.195

	 Created on:   	3/19/2022 4:25 PM

	  

	 Filename:     	Create-WindowsUpdateDailyTask

	===========================================================================

	.DESCRIPTION

		Creates a script to check windows updates and an associated scheduled task to run script daily

#>



$TaskScript = @'

function Get-SystemUptime

{

	$lastBoot = (GCIM Win32_OperatingSystem).LastBootUpTime

	$currentTime = Get-Date

	$UpTime = $currentTime - $lastBoot

	return $UpTime

}



try { Get-InstalledModule -Name PSWindowsUpdate -ErrorAction Stop }

catch

{

	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force ; Install-Module -Name PSWindowsUpdate -Force

}







$TimeSpan = New-TimeSpan -Days 7

# Check if a user is logged on 

$NotLoggedOn = [string]::IsNullOrEmpty((GCIM WIn32_ComputerSystem).UserName)



if ($NotLoggedOn -and ((Get-SystemUptime) -gt $TimeSpan))

{

	Import-Module -Name PSWindowsUpdate

	Install-WindowsUpdate -Install -AcceptAll -AutoReboot 

}

elseif ($NotLoggedOn)

{

	Install-WindowsUpdate -Install -AcceptAll

}

'@



# Create a script directory

if (!(test-path "$env:SystemDrive\automation")) { mkdir "$env:SystemDrive\automation" }



# Create a scheduled task to run script daily



$TaskName = 'Check for Windows Updates'

$RunTime = '11PM'

$TaskScript | out-file C:\automation\WindowsUpdate.ps1 -encoding utf8

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-executionpolicy bypass -file %HOMEDRIVE%\automation\WindowsUpdate.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At $RunTime

$principal = New-ScheduledTaskPrincipal -UserId "NT Authority\SYSTEM"

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal

Register-ScheduledTask $taskName -InputObject $task

Start-ScheduledTask -TaskName $taskName