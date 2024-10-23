<#
.SYNOPSIS
    Update Dell Drivers using Dell Command Update. 

.DESCRIPTION
    Please make sure that Dell Command update is installed on the machines.
    
.NOTES
    Filename: DCU-Remediate.ps1
    1.0   -   Script created

#>

$DCUExists32 = Test-Path "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
write-host "Does C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe exist? $DCUExists32"
$DCUExists64 = Test-Path "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
write-host "Does C:\Program Files\Dell\CommandUpdate\dcu-cli.exe exist? $DCUExists64"

if ($DCUExists32 -eq $true) {
    $DCU_DIR = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
}    
elseif ($DCUExists64 -eq $true) {
    $DCU_DIR = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
}

if (!$DCUExists32 -or !$DCUExists64) {

$DCU_report = "C:\Temp\Dell_report"
$DCU_category = "driver"  # bios,firmware,driver,application,others#Check for 32bit or 64bit
$DCU_Severity = "security,critial,recommended"

$DCUExists = Test-Path "$DCU_DIR"
write-host "About to run $DCU_DIR. Lets be sure to be sure. Does it exist? $DCUExists"

Start-Process "$($DCU_DIR)" -ArgumentList "/scan -updateType=$DCU_category -report=$($DCU_report)" -Wait
write-host "Checking for results."

$XMLExists = Test-Path "$DCU_Report\DCUApplicableUpdates.xml"
if (!$XMLExists) {
        write-host "Something went wrong. Waiting 60 seconds then trying again..."
     Start-Sleep -s 60
    Start-Process "$($DCU_DIR)" -ArgumentList "/scan -updateType=$DCU_category -report=$($DCU_report)" -Wait
    $XMLExists = Test-Path "$DCU_report\DCUApplicableUpdates.xml"
    write-host "Did the scan work this time? $XMLExists"
}

try{
    Start-Process $DCU_DIR -ArgumentList "/applyUpdates -silent -reboot=disable -updateType=$DCU_category -updateSeverity=$DCU_Severity -updatesNotification=disable -outputlog=$DCU_report" -Wait
    Write-Output "Installation completed"
}catch{
    Write-Error $_.Exception
}

}
            
