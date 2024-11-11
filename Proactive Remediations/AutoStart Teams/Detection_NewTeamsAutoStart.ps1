<#
Description:
This PowerShell script is designed to check the existence of a specific registry key for New Teams under HKEY_CURRENT_USER, and if the key is found, update its State value to 1 (Disable).
The script includes detailed status messages for reporting the steps being executed, including the key’s existence and the value update.
Author: Eswar Koneti
Date:17-Aug-2024
Name:Detection_NewTeamsAytiStart.ps1
#>

# Define the registry path and value
$regPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe"
$regKey = "TeamsTfwStartupTask"
$valueName = "State"

# Combine the path and key for ease of use
$fullRegPath = Join-Path -Path $regPath -ChildPath $regKey

# Check if the registry key exists
if (Test-Path -Path $fullRegPath) {
    #Write-Host "Registry key found: $fullRegPath"
    
    try {
        # Attempt to get the current state value
        $currentState = Get-ItemProperty -Path $fullRegPath -Name $valueName -ErrorAction Stop
        
        # Check if the value is retrieved and its current value
        if ($null -ne $currentState) {
            $stateValue = $currentState.$valueName
     #       Write-Host "Current value of '$valueName': $stateValue"
            
            # Check if the state value is already 1
            if ($stateValue -eq 1) {
                Write-Host "New Teams auto Start is already disabled. No action needed."
                exit 0  # Exit with status code 0 to indicate success and no action needed
            } else {
                Write-Host "Auto start is not disabled, remediation is required."
                exit 1  # Exit with status code 1 to indicate that remediation is needed
            }
        } else {
            Write-Host "Auto start value for New teams is  not found, No action needed'"
            exit 0  # Exit with status code 0 to indicate that No remediation is required
        }
    } catch {
        Write-Host "Error accessing registry value: $_"
        exit 0  # Exit with status code 0 to indicate that No remediation is required
    }
} else {
    Write-Host "New Teams not found: No action needed"
    exit 0  # Exit with status code 0 to indicate that remediation is required
}

#Write-Host "Detection script execution completed."
