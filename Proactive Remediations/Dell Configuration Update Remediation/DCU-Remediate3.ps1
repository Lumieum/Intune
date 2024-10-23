<#
.SYNOPSIS
    Update Dell Drivers using Dell Command Update. 

.DESCRIPTION
    Please make sure that Dell Command update is installed on the machines.
    
.NOTES
    Filename: DCU-Remediate.ps1
    1.0   -   Script created.
    1.1   -   Modified DCU_Severity setting to "Security,critial".
    1.2   -   Fixed error with logging and update command.
    1.3   -   Corrected spelling error in DCU_Severity

#>

$DCU_DIR = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
$DCU_Report = "C:\Temp\DCU_Report\"
$DCU_Log = "C:\Temp\DCU_Report\DCU.log"
$DCU_category = "driver,application"  # bios,firmware,driver,application,others#Check for 32bit or 64bit
$DCU_Severity = "security,critical"

Start-Process "$($DCU_DIR)" -ArgumentList "/scan -updateType=$DCU_category -report=$($DCU_Report)" -Wait
write-host "Checking for results."

$XMLExists = Test-Path "$DCU_Report\DCUApplicableUpdates.xml"
if (!$XMLExists) {
        write-host "Something went wrong. Waiting 60 seconds then trying again..."
     Start-Sleep -s 60
    Start-Process "$($DCU_DIR)" -ArgumentList "/scan -updateType=$DCU_category -report=$($DCU_Report)" -Wait
    $XMLExists = Test-Path "$DCU_Report\DCUApplicableUpdates.xml"
    write-host "Did the scan work this time? $XMLExists"
}

try{
    Start-Process "$($DCU_DIR)" -ArgumentList "/applyUpdates -silent -reboot=disable -updateType=$DCU_category -updateSeverity=$DCU_Severity -outputlog=$DCU_Log" -Wait
    Write-Output "Installation completed"
}catch{
    Write-Error $_.Exception
}
            
