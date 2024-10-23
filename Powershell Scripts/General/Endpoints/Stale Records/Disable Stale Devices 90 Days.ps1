$dt = (Get-Date).AddDays(-90)
$params = @{
	accountEnabled = $false
}

$Devices = Get-MgDevice -All | Where {$_.ApproximateLastSignInDateTime -le $dt}
foreach ($Device in $Devices) { 
   Update-MgDevice -DeviceId $Device.Id -BodyParameter $params 
}