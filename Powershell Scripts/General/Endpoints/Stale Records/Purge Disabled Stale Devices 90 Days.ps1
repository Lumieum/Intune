$dt = (Get-Date).AddDays(-90)
$Devices = Get-MgDevice -All | Where {($_.ApproximateLastSignInDateTime -le $dt) -and ($_.AccountEnabled -eq $false)}
foreach ($Device in $Devices) {
   Remove-MgDevice -DeviceId $Device.Id
}