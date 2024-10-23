Param(
	[string]$targetGroup
)
#**********************************************************************************************************#
#Version 0.2

$ScriptDir = Switch ($Host.name) {
	'Visual Studio Code Host' { Split-Path $psEditor.GetEditorContext().CurrentFile.Path }
	'Windows PowerShell ISE Host' { Split-Path -Path $psISE.CurrentFile.FullPath }
	'ConsoleHost' { $PSScriptRoot }
}

#$targetGroup = "Students"
$targetGroup = "Secretaries"

if (!($targetGroup)) {
	Write-Host "You must provide a group name as identifiable by 365 by passing them as an Identity to the Get-UnifiedGroup cmdlet"
	Write-Host "https://docs.microsoft.com/en-us/powershell/module/exchange/get-unifiedgroup?view=exchange-ps"
	Write-Host "Get-UnifiedGroup -identity `"IT Department`" - Members of `"IT Department`" will be forwarded to GSuite"
	Exit
}
Else {

	Write-Host "Finding members of 365 group $($targetGroup)"
	
}

###pause

$SyncType = "365"
$GSuiteDomain = "livoniapublicschools.org"
$EmailAlias = "gmfw.livoniapublicschools.org"
$WantedForwards = "@livoniapublicschools.org"
#Added to prevent students being forwarded to alias, and instead to their own sub domain. No alias is required.
#If($targetGroup -match "student"){ $GSuiteDomain = "gmfw.livoniapublicschools.org" ; $EmailAlias = $null}
If($targetGroup -match "student" -and $targetGroup -notmatch "service"){ $GSuiteDomain = "livoniapublicschools.org" ; $EmailAlias = $null}
#**********************************************************************************************************#

# Set script location for PowerShell to script directory

Push-Location $ScriptDir

#Load Support Functions
$SupportingScript = "$ScriptDir\Config\Support.ps1"
. $SupportingScript


$newMailContactsEmailOutput = $null 
$removedMailContactsEmailOutput = $null 
$errorsMailContactsEmailOutput = $null 

$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()


$LogFilePath = "$($ScriptDir)\Logs\MailContacts_Log-$($TypeOfUsers).csv"
$LastRunLogFilePath = $LogFilePath.Replace(".csv", "-lastrun.csv")
		

		
#**********************************************************************************************************#
		
Write-Host "Pausing for 2 Seconds before we begin."
Start-Sleep -Seconds 2
		
$Host.PrivateData.ErrorForegroundColor = 'Yellow'
		
 
#START OF SCRIPT BODY
		
Get-PSSession | Remove-PSSession

		
If ($SyncType -notmatch "365" -and !(Get-Module ActiveDirectory)) {
		 
	Write-Host "Attempting to import ActiveDirectory PS Module."
	Import-Module ActiveDirectory
		 
	If (!(Get-Module ActiveDirectory)) {
		Write-Host "Cannot find ActiveDirectory PS Module. Bye."
		Exit
	}
}
		
		
				 
If (Test-Path .\Config\365User.dat) {
			 
		
	$KeyFile = $ScriptDir + "\Config\notifications.dat"
	$365Creds = $ScriptDir + "\Config\365User.dat"

	$365User = (Get-Content $365Creds)[0]
		
	$Credentials = New-Object -TypeName System.Management.Automation.PSCredential `
		-ArgumentList $365User, ( (Get-Content  $365Creds | Select-Object -Skip 1) | ConvertTo-SecureString -Key `
		(Get-Content $KeyFile | Select-Object -Skip 1) )

	$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credentials -Authentication Basic -AllowRedirection -ErrorAction SilentlyContinue
	Import-PSSession $Session -DisableNameChecking -AllowClobber

}
ELSE {
		
	$Credentials = Get-Credential -Message "Enter Office365 Administrator (Or delegated) username and password." -UserName "username@example.com"

	$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credentials -Authentication Basic -AllowRedirection -ErrorAction SilentlyContinue
	Import-PSSession $Session -DisableNameChecking -AllowClobber
}

If ($Session) {
	Write-Host "Successfully connected to 365. Storing credentials"
		
	$KeyFile = $ScriptDir + "\Config\notifications.dat"
	$Credentials.UserName | Set-Content -Path ($ScriptDir + "\Config\365User.dat")
	$Credentials.Password | ConvertFrom-SecureString -key (Get-Content $KeyFile | Select-Object -Skip 1) | Add-Content ($ScriptDir + "\Config\365User.dat")
		

}
ELSE {
	Write-Output "Error connecting to 365. Terminating."
	Break
}
			 

If ($Session.State -notlike "open*") {
	Write-Host "Unable to connect to Exchange/O365"
	EmailNotification "Exchange -> Gmail Configuration - $UserType" "<br>Cannot connect to Exchange Server - $MailServer. Terminating Error.<br>You may want to delete the 365user.dat file in the config if your username/password is wrong.<br>"
	Exit
}
#>
		
#####################################################################################################################
		
#Clear Last Run Log File on execute
If (Test-Path $LastRunLogFilePath) {
	Remove-Item $LastRunLogFilePath -Force
}
		
		
If ($SyncType -match "365") {
		
		
	$newMailContactsEmailOutput = $newMailContactsEmailOutput + "<hr><h2>Creating Mail Forwards for Users</h2>Syncing Google Users from 365.<br><br>Forwards will be added/udpated to any users requiring them `
		in 365<br>"
		
}
		

		
#First line of email body
$newMailContactsEmailOutput = $newMailContactsEmailOutput + "<h2>Adding Group Fowards</h2>Adding Gmail forwards for all users in 365.<br><br>"
		
If ($EmailAlias) {
	$DestinationGSuiteDomain = "gmfw." + $GSuiteDomain.ToString()
}
Else {
	$DestinationGSuiteDomain = "student." + $GSuiteDomain.ToString()
}


Write-host "Mail forwards per group will happen after this."
###pause

Function ForwardGroupMembers ($groupName) { 

	Write-Host "Getting all members for group name $($groupName)"
	$TimeSeconds = (Measure-Command { $groupMembers = Get-UnifiedGroup -Identity $groupName | Get-UnifiedGroupLinks -LinkType Members -ResultSize Unlimited }).TotalSeconds
	Write-Host " Retrieved all $(@($groupName.Count)) members from Group $($groupName) in $($TimeSeconds) seconds"
	
	If (!($groupMembers)) {
		Write-Host "No members found in Group. Exiting."
		Exit
	}
	
	foreach ($User in $groupMembers) {


		$DestinationAddress = $null
		$DestinationAddress = $User.Alias + "@" + $DestinationGSuiteDomain
		
		Write-Host "Setting $($User.PrimarySmtpAddress) to forward to $($DestinationAddress). Is that correct?"
		###pause

		If ($User.PrimarySmtpAddress -match $WantedForwards) {
		
			If (!($User.ForwardingSmtpAddress)) {

				#Set-Mailbox -Identity "$($User.Alias)" -DeliverToMailboxAndForward $true -ForwardingSmtpAddress "$($DestinationAddress)"
				Set-Mailbox -Identity "$($User.PrimarySmtpAddress)" -DeliverToMailboxAndForward $true -ForwardingSmtpAddress "$($DestinationAddress)"
				Write-Log "Added NEW forward for mailbox user $($User.PrimarySmtpAddress) to $($DestinationAddress)"
				$newMailContactsEmailOutput = $newMailContactsEmailOutput + "Added Mail Forward: User: <b>$($User.WindowsEmailAddress)</b> to <b>$($DestinationAddress)</b><br>"

			}
			ELSE {

				If ($User.ForwardingSmtpAddress -match $EmailAlias) {
					
					###pause
					###pause

					If ($User.ForwardingSmtpAddress -eq $DestinationAddress) {

						Write-Log "No change required for $($User.WindowsEmailAddress)"
					}
					Else {
						Write-Log "Updating Google Forward based on a change to 365 local alias/address"
						#Set-Mailbox -Identity "$($User.Alias)" -DeliverToMailboxAndForward $true -ForwardingSmtpAddress "$($DestinationAddress)"
						Set-Mailbox -Identity "$($User.PrimarySmtpAddress)" -DeliverToMailboxAndForward $true -ForwardingSmtpAddress "$($DestinationAddress)"
						Write-Log "Updated forward for mailbox user $($User.PrimarySmtpAddress) to $($DestinationAddress)"
						$newMailContactsEmailOutput = $newMailContactsEmailOutput + "Updated Mail Forward: User: <b>$($User.WindowsEmailAddress)</b> to <b>$($DestinationAddress)</b><br>"
					}

				}
				Else {
					Write-Log "WARNING - Forward defined for this user already and is not GSuite related, not updating. User: $($User.WindowsEmailAddress) - Forwarding to $($User.ForwardingSmtpAddress)"
					$newMailContactsEmailOutput = $newMailContactsEmailOutput + "WARNING Mail Forward set to something other than GSuite. Skipping. : User: <b>$($User.WindowsEmailAddress)</b> to <b>$($User.ForwardingSmtpAddress)</b><br>"
				}
			}


		}
		Else {

			Write-Host "User $($User.WindowsEmailAddress) does not match wanted user. Continuing."
		}

		Write-Host "Will continue to next user after this"
		###pause
		Write-Host "Proceeding"
	}

	#End Function
}

ForwardGroupMembers $targetGroup

$newMailContactsEmailOutput = $newMailContactsEmailOutput + "<br><hr>"
		
		
Write-Host "Pausing for 10 Seconds before disconnecting from 365."
Start-Sleep -Seconds 10

$newMailContactsEmailOutput = $newMailContactsEmailOutput + "<br><hr>"
		
$errorsMailContactsEmailOutput = $errorsMailContactsEmailOutput + "<br><hr>"

If (!$changesMade) {
			
	EmailNotification "Exchange -> Gmail Configuration - $SyncType" "<br>No changes were required to Exchange on this execution.<br>" $EmailNotificationAddress
	
}
ELSE {
			

	EmailNotification "Exchange -> Gmail Configuration - $SyncType" "<br>The following changes were made to your Exchange infrastructure on this execution:`
			<h1>Additions</h2>$newMailContactsEmailOutput<h1>Removals</h1>$errorsMailContactsEmailOutput" $EmailNotificationAddress
		
}


#Stop Clock
$StopWatch.Stop()
		

#Close Exchange session
If ($Session) {
	Get-PSSession | Remove-PSSession
	#Remove-PSSession $Session
}