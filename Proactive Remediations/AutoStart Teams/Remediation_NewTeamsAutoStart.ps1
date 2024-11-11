<#
Description:
This PowerShell script is designed to check the existence of a specific registry key for New Teams under HKEY_CURRENT_USER, and if the key is found, update its State value to 1 (Disable).
The script includes detailed status messages for reporting the steps being executed, including the key’s existence and the value update.
Author: Eswar Koneti
Date:17-Aug-2024
Name:Remediation_NewTeamsAytiStart.ps1
#>

# Define the registry path and value
$regPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe"
$regKey = "TeamsTfwStartupTask"
$valueName = "State"

# Combine the path and key for ease of use
$fullRegPath = Join-Path -Path $regPath -ChildPath $regKey

# Check if the registry key exists
if (Test-Path -Path $fullRegPath) {
    Write-Host "Registry key found: $fullRegPath"
    
    # Attempt to get the current state value
    try {
        $currentState = Get-ItemProperty -Path $fullRegPath -Name $valueName -ErrorAction Stop
        
        # Check if the value is retrieved
        if ($null -ne $currentState) {
            #Write-Host "Current value of '$valueName': $($currentState.$valueName)"
            
            # Update the State value to 1
            Set-ItemProperty -Path $fullRegPath -Name $valueName -Value 1

            # Verify the update
            $updatedState = Get-ItemProperty -Path $fullRegPath -Name $valueName -ErrorAction Stop
            if ($updatedState.$valueName -eq 1) {
             #  Write-Host "Successfully updated '$valueName' to 1"
                Write-Host "New Teams auto start is disabled"
            } else {
                Write-Host "Failed to disable New Teams auto start"
            }
        } else {
            Write-Host "The registry key '$regKey' does not have a value named '$valueName'"
        }
    } catch {
        Write-Host "Error accessing registry value: $_"
    }
} else {
    Write-Host "Registry key not found: $fullRegPath"
}

