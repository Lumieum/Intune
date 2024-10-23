######## Copyright Company="Microsoft Corporation" ########
######## Copyright (c) Microsoft Corporation.  All rights reserved. ########

<# 
    .SYNOPSIS
        Script to deploy Minecraft: Education Edition V4

    .DESCRIPTION
        This script checks if Minecraft: Education Edition v4 already exists as a provisioned package and if not deploys Minecraft: Education Edition as provisioned package #
        In case provisioned package is present it checks if minecraft is present in current user profile and deploys if not #
        In case minecraft exists both as a provisioned package as well in the current user profile, script exits #
#>

$global:myLogText = ""
$dir = Get-Location
$opfile = Join-Path $dir "InstallResults.log"

$dir = Join-Path $dir "\Files"
$build = [System.Environment]::OSVersion.Version.Build
$arch = $Env:Processor_Architecture;
$pslog = $null;

# Function to appends details to log
Function Append-Log
{
Param ([string] $msg, [string] $pslog, [string] $opfile, [bool] $writehost)
    $msg += "`r`n"
    if ($writehost)
    {
        write-host $msg
    }
    $global:myLogText +=  $pslog + $msg
    $global:myLogText | Out-File $opfile
}

# Function to appends details to log and exit
Function AppendAndExit-Log
{
Param ([string] $msg, [string] $pslog, [string] $opfile, [bool] $writehost)
    Append-Log $msg $pslog $opfile $writehost
    write-host "Press any key to exit ..."

    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Exit
}

#Function to re

# Function to retrieve names of packages
Function Get-PackageName
{
Param ([string] $name, [string ] $type, [string] $arch = '')
    $filename = Get-ChildItem -Path $dir -Filter *$name*$arch*$type | select -ExpandProperty Name -First 1
    Append-Log $filename $pslog $opfile $false
    return $filename
}

Function Get-VersionFromAppxBundleName
{
Param ([string] $fileName)
    $name = [io.path]::GetFileNameWithoutExtension($fileName)
    $split = $name.Split("{_}")
    if ($split.Length -ne 2) {
        throw [System.IO.FileNotFoundException] "Incorrect $fileName"
    }

    return $split[1]
}

# Package Files and Package Names, these values are picked up directly #
$packageFamilyName = "Microsoft.MinecraftEducationEdition_8wekyb3d8bbwe"
$packageName = "Microsoft.MinecraftEducationEdition"
$appxbundle = Get-PackageName "Microsoft.MinecraftEducationEdition" "appxbundle"
$appxbundleversion = Get-VersionFromAppxBundleName $appxbundle
$licensefile = Get-PackageName "Microsoft.MinecraftEducationEdition" "xml"

#Dependencies
$deppackageX64 = Get-PackageName "Microsoft.VCLibs" "Appx" "x64"
$deppackageX86 = Get-PackageName "Microsoft.VCLibs" "Appx" "x86"

# Function to check if the provisioned package specified is already installed 
Function Test-ProvisionedPackage
{
Param ([bool] $versionTest = $false)
    Append-Log "Get-AppxProvisionedPackage -Online | where DisplayName -EQ $packageName" $pslog $opfile $false
    $provisionedPackage = Get-AppxProvisionedPackage -Online | where DisplayName -EQ $packageName
    if ($provisionedPackage.PackageFamilyName -eq $familyName) 
    {
        $actualVersion = [string]$provisionedPackage.Version;
        if ($versionTest -and [bool]([version]$provisionedPackage.Version -LT [version]$appxbundleversion)) {
            Append-Log "App Provisioned Package Does Not Exist. (Expected version $appxbundleversion, but got $($provisionedPackage.Version))" $pslog $opfile $false
            return $false
        }

        Append-Log "App Provisioned Package Exists (Found app: $familyName With version: $actualVersion)" $pslog $opfile $false
        return $true
    }
    else
    {
        Append-Log "App Provisioned Package Does Not Exist." $pslog $opfile $false
        return $false
    }
}

Function Test-PackageName
{
Param ([bool] $versionTest = $false, [string] $name = $packageName, [string] $familyName = $packageFamilyName)
    $minecraftpackageforuser = Get-AppxPackage | where Name -EQ $name        
    Append-Log "Get-AppxPackage | where Name -EQ $name" $pslog $opfile $false
    if ($minecraftpackageforuser.PackageFamilyName -eq $familyName) 
    {
        if ($versionTest -and [bool]([version]$minecraftpackageforuser.Version -LT [version]$appxbundleversion)) {
            Append-Log "App Package Does Not Exist. (Expected version $appxbundleversion, but got $($minecraftpackageforuser.Version))" $pslog $opfile $false
            return $false
        }

        Append-Log "App Package Exists (Found app: $familyName With version: $($minecraftpackageforuser.Version))" $pslog $opfile $false
        return $true
    }
    else
    {
        Append-Log "App Package Does Not Exist." $pslog $opfile $false
        return $false
    }
}

# Function to check if the app package specified is already installed
Function Test-Package
{
Param ([string] $packagename)
    $minecraftpackageforuser = Get-AppxPackage | where PackageFullName -EQ $packagename | select -ExpandProperty PackageFullName        
    Append-Log "Get-AppxPackage | where PackageFullName -EQ $packagename | select -ExpandProperty PackageFullName" $pslog $opfile $false
    if ($minecraftpackageforuser -eq $packagename)
    {
        Append-Log "App Package Exists" $pslog $opfile $false
        return $true
    }
    else
    {
        Append-Log "App Package Does Not Exist" $pslog $opfile $false
        return $false
    }
}

# Function to check if the app package version currently installed is lesser than the new package
Function Test-PackageVersion
{
Param ([string] $packagename)
    ($name, $version, $arch, $identifier) = $packagename -Split '[_]';
    # In case we want to check for provisioned package $currversion = Get-AppxProvisionedPackage -Online | where DisplayName -EQ $name | select -ExpandProperty version
    $currversion = Get-AppxPackage | where Name -EQ $name | select -ExpandProperty version -First 1
    Append-Log "Get-AppxPackage | where Name -EQ $name | select -ExpandProperty version -First 1" $pslog $opfile $false
    if (!$currversion)
    {
        return $true
    }
    return [bool]([version]$currversion -LT [version]$version )
}

# Function which runs dism for the specified packages
Function Invoke-Dism
{
    $args = "/Online /Add-ProvisionedAppxPackage /LogPath:`"$dir\dism.log`" /LogLevel:1 /PackagePath:`"$dir\$appxbundle`" /LicensePath:`"$dir\$licensefile`""
    if ($arch -eq "amd64")
        {
            # Adding dependency packages to dism install only if a newer version does not exist
            if(Test-PackageVersion $deppackageX64)
            {
                $args = $args + " /DependencyPackagePath:`"{0}\{1}`"" -f  $dir, $deppackageX64
                Append-Log "$deppackageX64 Does Not Exist, Adding to Dism install" $pslog $opfile $false
            }
            else
            {
                Append-Log "$deppackageX64 Exists, Skipping from Dism install" $pslog $opfile $false
            }
        }

        # Adding dependency packages to dism install only if a newer version does not exist
        if(Test-PackageVersion $deppackageX86)
        {
            $args = $args + "/DependencyPackagePath:`"{0}\{1}`"" -f  $dir, $deppackageX86
            Append-Log "$deppackageX86 Does Not Exist, Adding to Dism install" $pslog $opfile $false
        }
        else
        {
            Append-Log "$deppackageX86 Exists, Skipping from Dism install" $pslog $opfile $false
        }

    Append-Log $args $pslog $opfile $false
    $msg = "Installation has begun. This may take several minutes."
    Append-Log $msg $pslog $opfile $true      
    $scriptpath = $MyInvocation.MyCommand.Path + " -path=" + $dir

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
       FileName = "Dism.exe"
       RedirectStandardError = $true
       RedirectStandardOutput = $true
       UseShellExecute = $false
       Arguments = $args
       Verb = "RunAs"
    }

    $p = New-Object System.Diagnostics.Process -Property @{
         StartInfo = $pinfo
    }
    $p.Start() | Out-Null
    #Do Other Stuff Here....
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    Append-Log $stdout $pslog $opfile $true
    Append-Log $stderr $pslog $opfile $true
    if($p.ExitCode -eq 0)
    {
        Append-Log "Dism Completed Successfully" $pslog $opfile $false
        return $true
    }
    else
    {
        Append-Log "Dism Did Not Complete Successfully" $pslog $opfile $false
        return $false
    }
}

# Function which runs add appx for the specified packages
Function Invoke-AddAppx
{
try
{
        write-host "`n`n`n`n`n`n`n" 
        $msg = "Installation has begun. This may take several minutes."
        Append-Log $msg $pslog $opfile $true
        if ($arch -eq "amd64")
        {
            $cmd = "Add-AppxPackage -Path `"{0}\{1}`" `
                     -DependencyPath `"{0}\{2}`", `"{0}\{3}`"" `
                     -f $dir, $appxbundle, $deppackageX64, $deppackageX86
            Append-Log $cmd $pslog $opfile $false


            $dependencyPath = ($deppackageX64, $deppackageX86) | %{ Join-Path $dir $_ }
            Add-AppxPackage -Path $dir\$appxbundle `
                -DependencyPath  $dependencyPath
            Append-Log $dependencyPath $pslog $opfile $false

            Append-Log "Waiting for 30 seconds to ensure install is complete, Please wait." $pslog $opfile $true
            Start-Sleep -s 30
            $ret = Test-PackageName $true
        }
        else
        {
            $cmd = "Add-AppxPackage -Path `"{0}\{1}`" `
             -DependencyPath `"{0}\{2}`"" `
             -f $dir, $appxbundle, $deppackageX86
            Append-Log $cmd $pslog $opfile $false

            $dependencyPath = $deppackageX86 | %{ Join-Path $dir $_ }
            Add-AppxPackage -Path $dir\$appxbundle `
             -DependencyPath $dependencyPath
            Append-Log $dependencyPath $pslog $opfile $false

            Append-Log "Waiting for 30 seconds to ensure install is complete, Please wait." $pslog $opfile $true
            Start-Sleep -s 30
            $ret = Test-PackageName $true
        }
        Append-Log $cmd $pslog $opfile $false
        if($ret)
        {
            return $true
        }
        else
        {
            Append-Log "Add Appx Failed" $pslog $opfile $false
            return $false
        }
    }
catch
    {
        $errormessage = $_.Exception.Message
        Append-Log $errormessage $pslog $opfile $true
        return $false
    }
}

# Function which parses appx logs to retrieve error details in case of failure
Function Parse-AppxLog
{
Param ([string] $packagename)
    $events = Get-WinEvent -LogName Microsoft-Windows-AppXDeploymentServer/Operational  -MaxEvents 1000 `
              | Where-Object { ($_.LevelDisplayName -eq "error") -and ($_.Message -like "*$packagename*")} `
              | Select -ExpandProperty Message
    if($events)
    {
        Append-Log "------------------- AppxDeployment Error event logs Start ----------------------" $pslog $opfile $false
        Append-Log $events $pslog $opfile $false
        Append-Log "------------------- AppxDeployment Error event logs End ----------------------" $pslog $opfile $false
    }
    else
    {
        Append-Log "No Appx Error Logs Found" $pslog $opfile $false
    }
}

# Checks provisioned and app package installs. 
# Returns 0 if both are good
# Returns 1 if provisioned package looks good but add package fails
# Returns 2 if add package looks good but provisioned package fails
# Returns 3 if both failed
Function Test-Install
{
    $msg = "Checking appx install"
    Append-Log $msg $pslog $opfile $false
    if (Test-PackageName $true)
    {
        $msg = "Appx install success, validated"
        Append-Log $msg $pslog $opfile $false
    }
    else
    {
        $msg = "Appx install failed, collecting logs"
        Append-Log $msg $pslog $opfile $false
        Parse-AppxLog $packageName
    }

    $msg = "Checking provisioned package install"
    Append-Log $msg $pslog $opfile $false
    if (Test-ProvisionedPackage $true)
    {
        $msg = "Provisioned Package install success, validated"
        Append-Log $msg $pslog $opfile $false
    }
    else
    {
        $msg = "Provisioned Package install Failed"
        Append-Log $msg $pslog $opfile $false
        Parse-AppxLog $packageName
    }
}

try
{
    # Enterprise components are supported only after build 10240. We should also check if this is an x86/amd64 device. We don't currently have an UWP arm build.
    if( $build -lt 14393 -or ($arch -ne "x86" -and $arch -ne "amd64"))
    {
        $msg = "This app cannot be installed on this version of Windows. It requires atleast Windows 10 Anniversary Update (Build 14393, Version 1607 or above.) and either a 64-bit or 32-bit processor."
        AppendAndExit-Log $msg $pslog $opfile $true
    }
    else
    {
        $msg = "{0} OS Version is supported, Proceeding to Install" -f $build
        Append-Log  $msg $pslog $opfile $false

        # Check if package exists
        $pexists = Test-PackageName $true
        if ($pexists)
        {
            $msg = "App package exists, proceeding to add provisionedpackage"
            Append-Log $msg $pslog $opfile $false
        }
        else
        {
            $msg = "App package does not exist, proceeding to add"
            Append-Log $msg $pslog $opfile $false
            if(Invoke-AddAppx)
            {
                $msg = "Minecraft: Education Edition has been installed on this windows account, We will try to install on all other accounts next"
                Append-Log $msg $pslog $opfile $true
            }
            else
            {
                $msg = "Minecraft: Education Edition failed to install on this windows account. `r`nWe will now retry the installation."
                Append-Log $msg $pslog $opfile $true
            }
        }

        $ppexists = Test-ProvisionedPackage $true
        if ($ppexists -and $build -ge 10586)
        {
            $msg = "Provisioned package already exists"
            Append-Log $msg $pslog $opfile $false
            $msg = "We skipped installation because looks like Minecraft: Education Edition Provisioning Package is already on your device."
            Append-Log $msg $pslog $opfile $true
        }
        else
        {
            $msg = "Provisioned package does not exist, proceeding to add"
            Append-Log $msg $pslog $opfile $false
            $dismresult = Invoke-Dism
            if($dismresult -eq $true)
            {
                $msg = "Minecraft: Education Edition has been installed for all windows accounts on this Computer. `r`nFor best results, Please restart and verify there are no pending app updates in the Windows Store."
                Append-Log $msg $pslog $opfile $true
            }
            else
            {
                $msg = "Minecraft: Education Edition Failed to install for the following possible reasons: `r`nSome Open Applications may block install, Please restart the computer, Close all applications and Try again. `r`nFor best results, Please Verify there are no pending app updates in the Windows Store.`r`nYour Administrator may have set policies to block installations, Please contact your Administrator."
                Append-Log $msg $pslog $opfile $true
            }
        }
        
        Test-Install $packagenameX64
    }
    $msg = "Script has completed execution, exiting"
    AppendAndExit-Log $msg $pslog $opfile $false
}
catch
{
    # A Number of operations performed below require elevation, exiting if not admin or if other issues are encountered
    $errormessage = $_.Exception.Message
    AppendAndExit-Log $errormessage $pslog $opfile $true
}
# SIG # Begin signature block
# MIIkegYJKoZIhvcNAQcCoIIkazCCJGcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBV7bg3GfwypGPc
# 7NYoKMDE2aaRDo5lNz7YGQGvLoH4yKCCDYEwggX/MIID56ADAgECAhMzAAABA14l
# HJkfox64AAAAAAEDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTgwNzEyMjAwODQ4WhcNMTkwNzI2MjAwODQ4WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDRlHY25oarNv5p+UZ8i4hQy5Bwf7BVqSQdfjnnBZ8PrHuXss5zCvvUmyRcFrU5
# 3Rt+M2wR/Dsm85iqXVNrqsPsE7jS789Xf8xly69NLjKxVitONAeJ/mkhvT5E+94S
# nYW/fHaGfXKxdpth5opkTEbOttU6jHeTd2chnLZaBl5HhvU80QnKDT3NsumhUHjR
# hIjiATwi/K+WCMxdmcDt66VamJL1yEBOanOv3uN0etNfRpe84mcod5mswQ4xFo8A
# DwH+S15UD8rEZT8K46NG2/YsAzoZvmgFFpzmfzS/p4eNZTkmyWPU78XdvSX+/Sj0
# NIZ5rCrVXzCRO+QUauuxygQjAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUR77Ay+GmP/1l1jjyA123r3f3QP8w
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDM3OTY1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAn/XJ
# Uw0/DSbsokTYDdGfY5YGSz8eXMUzo6TDbK8fwAG662XsnjMQD6esW9S9kGEX5zHn
# wya0rPUn00iThoj+EjWRZCLRay07qCwVlCnSN5bmNf8MzsgGFhaeJLHiOfluDnjY
# DBu2KWAndjQkm925l3XLATutghIWIoCJFYS7mFAgsBcmhkmvzn1FFUM0ls+BXBgs
# 1JPyZ6vic8g9o838Mh5gHOmwGzD7LLsHLpaEk0UoVFzNlv2g24HYtjDKQ7HzSMCy
# RhxdXnYqWJ/U7vL0+khMtWGLsIxB6aq4nZD0/2pCD7k+6Q7slPyNgLt44yOneFuy
# bR/5WcF9ttE5yXnggxxgCto9sNHtNr9FB+kbNm7lPTsFA6fUpyUSj+Z2oxOzRVpD
# MYLa2ISuubAfdfX2HX1RETcn6LU1hHH3V6qu+olxyZjSnlpkdr6Mw30VapHxFPTy
# 2TUxuNty+rR1yIibar+YRcdmstf/zpKQdeTr5obSyBvbJ8BblW9Jb1hdaSreU0v4
# 6Mp79mwV+QMZDxGFqk+av6pX3WDG9XEg9FGomsrp0es0Rz11+iLsVT9qGTlrEOla
# P470I3gwsvKmOMs1jaqYWSRAuDpnpAdfoP7YO0kT+wzh7Qttg1DO8H8+4NkI6Iwh
# SkHC3uuOW+4Dwx1ubuZUNWZncnwa6lL2IsRyP64wggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIWTzCCFksCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAQNeJRyZH6MeuAAAAAABAzAN
# BglghkgBZQMEAgEFAKCB4DAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgF4h17tFO
# svFjbVO4gFXk9EsIEeUYoqhFSU1vSKHKXucwdAYKKwYBBAGCNwIBDDFmMGSgPoA8
# AE0AaQBuAGUAYwByAGEAZgB0ACAAUABvAHcAZQByAHMAaABlAGwAbAAgAEkAbgBz
# AHQAYQBsAGwAZQByoSKAIGh0dHBzOi8vZWR1Y2F0aW9uLm1pbmVjcmFmdC5uZXQg
# MA0GCSqGSIb3DQEBAQUABIIBAIBSIxPzIEDjbV9YL4rnPtLDcdXanz/UqJ7Tz30E
# HhFi+JMT0fm8JPLOk8B/cnsvOpnYOecukpW5wBZ0z/xSZhUnFW5zUWilBIsvaoMk
# NT65wqpTJuz/5rl5oMR0T+21goDVCnWdvatETsbVrK9kQaUkMFKhB0UjRt+HIdD8
# zIuQtsq/PIIRhN0+jV61XoWsFpRdCoG9LYxCMG48WmWYWqiEQ3nC9VHvVH0fuPdn
# ew+L6/5UlzmVDCmtwnWJTPYe1tAfO6MMHIcBPyvF7ISBTZgs5bExsYmgyQ61r0zk
# Tb0rqucGzYC1mKepEi6odcA5Ccj3Am8N6q15Nm55IoBkEcGhghOnMIITowYKKwYB
# BAGCNwMDATGCE5MwghOPBgkqhkiG9w0BBwKgghOAMIITfAIBAzEPMA0GCWCGSAFl
# AwQCAQUAMIIBVAYLKoZIhvcNAQkQAQSgggFDBIIBPzCCATsCAQEGCisGAQQBhFkK
# AwEwMTANBglghkgBZQMEAgEFAAQg/c67f117U7jih3VUADRjNklOAxoVfK8XjO5D
# r9tUZigCBlvbp6we7RgTMjAxODExMTMyMzExMjMuMTcxWjAHAgEBgAIB9KCB0KSB
# zTCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UE
# CxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVz
# IFRTUyBFU046NTdDOC0yRDE1LTFDOEIxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2Wggg8TMIIGcTCCBFmgAwIBAgIKYQmBKgAAAAAAAjANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcNMjUwNzAxMjE0NjU1WjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0VBDVpQoAgoX77XxoSyxfxcPlYcJ2tz5m
# K1vwFVMnBDEfQRsalR3OCROOfGEwWbEwRA/xYIiEVEMM1024OAizQt2TrNZzMFcm
# gqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQedGFnkV+BVLHPk0ySwcSmXdFhE24oxhr5
# hoC732H8RsEnHSRnEnIaIYqvS2SJUGKxXf13Hz3wV3WsvYpCTUBR0Q+cBj5nf/Vm
# wAOWRH7v0Ev9buWayrGo8noqCjHw2k4GkbaICDXoeByw6ZnNPOcvRLqn9NxkvaQB
# wSAJk3jN/LzAyURdXhacAQVPIk0CAwEAAaOCAeYwggHiMBAGCSsGAQQBgjcVAQQD
# AgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7fEYbxTNoWoVtVTAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNV
# HSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVo
# dHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29D
# ZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAC
# hj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1
# dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0gAQH/BIGVMIGSMIGPBgkrBgEEAYI3LgMw
# gYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9QS0kvZG9j
# cy9DUFMvZGVmYXVsdC5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8A
# UABvAGwAaQBjAHkAXwBTAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQEL
# BQADggIBAAfmiFEN4sbgmD+BcQM9naOhIW+z66bM9TG+zwXiqf76V20ZMLPCxWbJ
# at/15/B4vceoniXj+bzta1RXCCtRgkQS+7lTjMz0YBKKdsxAQEGb3FwX/1z5Xhc1
# mCRWS3TvQhDIr79/xn/yN31aPxzymXlKkVIArzgPF/UveYFl2am1a+THzvbKegBv
# SzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon/VWvL/625Y4zu2JfmttXQOnxzplmkIz/
# amJ/3cVKC5Em4jnsGUpxY517IW3DnKOiPPp/fZZqkHimbdLhnPkd/DjYlPTGpQqW
# hqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/fmNZJQ96LjlXdqJxqgaKD4kWumGnEcua
# 2A5HmoDF0M2n0O99g/DhO3EJ3110mCIIYdqwUB5vvfHhAN/nMQekkzr3ZUd46Pio
# SKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0cs0d9LiFAR6A+xuJKlQ5slvayA1VmXqH
# czsI5pgt6o3gMy4SKfXAL1QnIffIrE7aKLixqduWsqdCosnPGUFN4Ib5KpqjEWYw
# 07t0MkvfY3v1mYovG8chr1m1rtxEPJdQcdeh0sVV42neV8HR3jDA/czmTfsNv11P
# 6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+NR4Iuto229Nfj950iEkSMIIE8TCCA9mg
# AwIBAgITMwAAAOj4ByM24VLVpgAAAAAA6DANBgkqhkiG9w0BAQsFADB8MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0xODA4MjMyMDI3MTJaFw0xOTExMjMy
# MDI3MTJaMIHKMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUw
# IwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1U
# aGFsZXMgVFNTIEVTTjo1N0M4LTJEMTUtMUM4QjElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAJElyU1HEr7emLIFAoLhoZP6H0G6tbgbfZReRnG1CkpluIWUa5BgsvSxffi3
# a4Cn1VY80NCBk2M7ixPYbQXBHDSVoXtQdm3L/Rh3qSN8Ey3bC+YGxhdzOfIXkTUT
# yGpHX+yBjtFXuu0v0bdWktC/w2i2eYqI24wlF9OlD+/fkk63GMgIgiKCSZ0NBSbp
# 5xMkdsWfbaj3C0aoxrOupr9bgvBboAW9z5sW7S/jsWFutG2rEtTDrP6331MGDv3/
# vM84zC4Le2pAMoz7045aBAJk5h407Q26Z3p2c/ENdU4VqggnKiyJR0L/jAAqc7G+
# n5YImEmoFJMrP6zOibaxh0y6A4MCAwEAAaOCARswggEXMB0GA1UdDgQWBBQUoGFL
# ZrDn7yklyhx/kZD7OBwqUzAfBgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVt
# VTBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtp
# L2NybC9wcm9kdWN0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYB
# BQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpL2NlcnRzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8E
# AjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQBJjhGX
# XjTl7TO/u/KdVA465C6jN7OcyodQrwUysneg0jF6pMvj2Y2JKHaRe+XHtrW9FLG4
# sCcPzlQgNzbDdytoTL2YjZWZ2mS0XUPPOVsC5Cx6w/m5WjmGjw1stDdCI0VliJb3
# eePxSc9pFxM8rNu+1PHBdvsVcHuXiZKFg56HSU+zXdAOeNJZu7Muj5ZhMOYrHldZ
# OVYHHb7cQgWNlgBY74AlQIxB9hc6SXOElB1xnadUIB/wsJxQ2n4kUVJfMqx15B0q
# Rl900+d1hNlqIz+7ehPSvZQCri04CcX1rqCgb/Oa4iUXIV+A1lqH8Y7dTu3D4bds
# 682AjTGZL01oUtJOoYIDpTCCAo0CAQEwgfqhgdCkgc0wgcoxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVy
# aWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjU3QzgtMkQx
# NS0xQzhCMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiUK
# AQEwCQYFKw4DAhoFAAMVAFAEOfN6KFsks16hDFBhhpSHMBYPoIHaMIHXpIHUMIHR
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxN
# aWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uQ2lwaGVyIE5U
# UyBFU046MjY2NS00QzNGLUM1REUxKzApBgNVBAMTIk1pY3Jvc29mdCBUaW1lIFNv
# dXJjZSBNYXN0ZXIgQ2xvY2swDQYJKoZIhvcNAQEFBQACBQDflb/0MCIYDzIwMTgx
# MTEzMjEyNjEyWhgPMjAxODExMTQyMTI2MTJaMHQwOgYKKwYBBAGEWQoEATEsMCow
# CgIFAN+Vv/QCAQAwBwIBAAICWdkwBwIBAAICGhcwCgIFAN+XEXQCAQAwNgYKKwYB
# BAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAaAKMAgCAQACAxbjYKEKMAgCAQACAx6E
# gDANBgkqhkiG9w0BAQUFAAOCAQEAFFL66LPVKVFdhWZYI9nERjEgtv1ztXegySjd
# JjQgiNFClhFOFr/hBceFvpK58fs6xZgn9Cmy9sH+jRsW7RS2WjmCmY0oZrXNrVwp
# Tl5iF25JvC2VD6iWDAvb6eLcwwJqvLfCMI/qS1VgrQSmGDgGYfhrBl/e9GXoDgey
# 42SJaEOn3BT6+Z558AFKLlPCTcuYjBDdNfYmhKoRNyDqgqHFurQqh+UMqTbHePhM
# oCpJQvOA3E7KgKsKZQoXCvuDNd6k/x3JjzuoKehOgrCIur8h4JKQojc3djCbb+7p
# rFVgz7eJHUGauMDxuHQBWOAz13xorH3x7RuzMUHgOk4hYibyFTGCAvUwggLxAgEB
# MIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAA6PgHIzbhUtWm
# AAAAAADoMA0GCWCGSAFlAwQCAQUAoIIBMjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcN
# AQkQAQQwLwYJKoZIhvcNAQkEMSIEILDLvwFRG/WHdNZqdE0K+02nG017I/IjCiR2
# KBd3WFjPMIHiBgsqhkiG9w0BCRACDDGB0jCBzzCBzDCBsQQUUAQ583ooWySzXqEM
# UGGGlIcwFg8wgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAOj4ByM24VLVpgAAAAAA6DAWBBSt8LY4ierApXQo3pQPVLtmFg7oPjANBgkq
# hkiG9w0BAQsFAASCAQApnF5CU3LrB83h8yXjGRV7vbOepkHzpHS+wl7HEgYBIdrX
# 7peilu0YnrDJag8bm5z6IUwsIg1bt8j53QfHY2oqXTTUi9AtpFkoNVC2PbVgl/7G
# BmRmWtnEO+m7Sl/nvtDxRfKts46Qu2/Tr5pFpWfq0Ql8tremk4EuNhqQvK0tFGh5
# UzyCO7dRWCD1GsOxPHVgKLyveflp4MzM5KmxdiOtXHAEClWFmNStDb9OmLFlkibq
# fyTCgAOO37xciwNFlfb+u7xgJNzXP21Y+Y7JDEmgv2j0SDNKLhezkiBfUW0LVN09
# hShUzQ0Zgh07OVFjedNpIRxYsAUuf4Ubtl+UJU0b
# SIG # End signature block
