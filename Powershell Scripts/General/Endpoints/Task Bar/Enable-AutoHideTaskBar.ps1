Function Enable-AutoHideTaskBar {
    #This will configure the Windows taskbar to auto-hide
    [cmdletbinding(SupportsShouldProcess)]
    [Alias("Hide-TaskBar")]
    [OutputType("None")]
    Param()

    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"
        $RegPath = 'HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    } #begin
    Process {
        if (Test-Path $regpath) {
            Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Auto Hiding Windows 10 TaskBar"
            $RegValues = (Get-ItemProperty -Path $RegPath).Settings
            $RegValues[8] = 3

            Set-ItemProperty -Path $RegPath -Name Settings -Value $RegValues

            if ($PSCmdlet.ShouldProcess("Explorer", "Restart")) {
                #Kill the Explorer process to force the change
                Stop-Process -Name explorer -Force
            }
        }
        else {
            Write-Warning "Can't find registry location $regpath."
        }
    } #process
    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
    } #end

}