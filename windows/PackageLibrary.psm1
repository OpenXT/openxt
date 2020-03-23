# Copyright (c) 2016 Assured Information Security, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

param (
  [string]$mirror = "",
  [string]$nsisVersion = "nsis-2.46",
  [string]$nsisBaseUrl = "http://prdownloads.sourceforge.net/nsis"
)

# Installer file names, to match in a mirror
$nsisInstaller     = $nsisVersion + "-setup.exe"
$nsisLogInstaller  = $nsisVersion + "-log.zip"
$gpgInstaller      = "gpg4win-vanilla-2.3.0.exe"
$cygwinInstaller   = "setup-x86.exe"
$szInstaller       = "7z920.msi"
$dotnetInstaller   = "dotnet45.exe"
$winddkInstaller   = "GRMWDK_EN_7600_1.ISO"
$wdkInstaller      = "wdksetup.exe"
$wdkCoInstaller    = "wdfcoinstaller.msi"
$sqlsce32Installer = "SSCERuntime_x86-ENU.exe"
$sqlsce64Installer = "SSCERuntime_x64-ENU.exe"
$vs2012Installer   = "vs_premium.exe"
$win8sdkInstaller  = "sdksetup.exe"
$wixInstaller      = "wix311.exe"
$capicomInstaller  = "capicom.msi"
$vs2012u4Installer = "VS2012.4.exe"
$pythonInstaller   = "python.msi"

# Installer URLs used by this script, and useful to setup a mirror
$nsisUrl     = $nsisBaseUrl + "/" + $nsisVersion + "-setup.exe"
$nsisLogUrl  = $nsisBaseUrl + "/" + $nsisVersion + "-log.zip"
$gpgUrl      = "https://files.gpg4win.org/gpg4win-vanilla-2.3.0.exe"
$cygwinUrl   = "https://www.cygwin.com/setup-x86.exe"
$szUrl       = "http://downloads.sourceforge.net/project/sevenzip/7-Zip/9.20/7z920.msi"
$dotnetUrl   = "http://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe"
$winddkUrl   = "http://download.microsoft.com/download/4/A/2/4A25C7D5-EFBE-4182-B6A9-AE6850409A78/GRMWDK_EN_7600_1.ISO"
$wdkUrl      = "http://download.microsoft.com/download/2/4/C/24CA7FB3-FF2E-4DB5-BA52-62A4399A4601/wdk/wdksetup.exe"
$wdkCoUrl    = "http://download.microsoft.com/download/0/5/F/05FD6919-6250-425B-86ED-9B095E54065A/wdfcoinstaller.msi"
$sqlsce32Url = "https://download.microsoft.com/download/F/F/D/FFDF76E3-9E55-41DA-A750-1798B971936C/ENU/SSCERuntime_x86-ENU.exe"
$sqlsce64Url = "https://download.microsoft.com/download/F/F/D/FFDF76E3-9E55-41DA-A750-1798B971936C/ENU/SSCERuntime_x64-ENU.exe"
$vs2012Url   = "http://download.microsoft.com/download/1/3/1/131D8A8C-95D8-41D4-892A-1DF6E3C5DF7D/vs_premium.exe"
$win8sdkUrl  = "http://download.microsoft.com/download/F/1/3/F1300C9C-A120-4341-90DF-8A52509B23AC/standalonesdk/sdksetup.exe"
$wixUrl      = "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311.exe"
$capicomUrl  = "http://download.microsoft.com/download/7/7/0/7708ec16-a770-4777-8b85-0fcd05f5ba60/capicom_dc_sdk.msi"
$vs2012u4Url = "http://download.microsoft.com/download/D/4/8/D48D1AC2-A297-4C9E-A9D0-A218E6609F06/VSU4/VS2012.4.exe"
$pythonUrl   = "https://www.python.org/ftp/python/2.7.11/python-2.7.11.msi"
$python64Url = "https://www.python.org/ftp/python/2.7.11/python-2.7.11.amd64.msi"

# Temp folder. For convenience only, do not change this value.
$tmp = $env:temp + "\"

# we need to make a list of packages available
# I don't know how to export a list to callers directly so simply return
# the list of packages as a string array
# Note: this list used to include "CAPICOM" (between "Wix" and "WDK8")
#     The URL for CAPICOM is broken, Microsoft probably dropped support for it.
#     CAPICOM doesn't seem to be needed anyway, so it was removed from the list.
function Get-Packages {
  return "GnuPG","Cygwin","NSIS","NSISAdvancedLogging","7Zip","DotNet45","WinDDK710","SqlSce32", "SqlSce64", "VS2012", "Win8SDK", "Wix", "WDK8", "VS2012U4", "PathAdditions"
}

# powershell inspects to import only installed modules
# but we want this to work without installing so use absolute path
# of modules in the same directory
$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module $ScriptDir\PerformDownload.psm1 -ArgumentList $mirror

# run a command with output redirection so that we wait
# and check the error code and fail if non-zero
function Invoke-CommandChecked {
  Write-Host "+$args"
  $command = $args[0]
  # doing "& *args" now would be good if it didn't take all the arguments and turn
  # it into a string and try and run that. We need to specify the command name separately.
  # we cannot remove items from arrays
  # see http://technet.microsoft.com/en-us/library/ee692802.aspx
  # so we turn the args into an arraylist instead
  $arglist = New-Object System.Collections.ArrayList
  $arglist.AddRange($args)
  # ... then remove the first argument
  $arglist.RemoveRange(0,1)
  & $command $arglist | Write-Host
  Write-Host "$command exited with code $LastExitCode"
  if ($LastExitCode -eq 3010) {
      Write-Host "Please reboot now and re-run this script"
  }
  if ($LastExitCode -ne 0) {
      Exit 3
  }
}

function Get-RedirectedUrl {

    $url = "http://wix.codeplex.com/downloads/get/762937"

    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()

    If ($response.StatusCode -eq "Found")
    {
        $response.GetResponseHeader("Location")
    }
}

# set up some read-only constant setups
$arch = ([System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE"))
if ($arch -eq "AMD64") {
    $programFiles32 = ([System.Environment]::GetEnvironmentVariable("ProgramFiles(x86)"))
    $programFiles64 = ([System.Environment]::GetEnvironmentVariable("ProgramFiles"))
} else {
    $programFiles32 = ([System.Environment]::GetEnvironmentVariable("ProgramFiles"))
}
$nsisdest = $programFiles32 + "\NSIS"
$pathelements = @( $nsisdest, "C:\cygwin\bin", "C:\WinDDK\7600.16385.1\bin\selfsign", $programFiles32+"\Windows Kits\8.0\bin\x86")

Function Test-NSIS {
  return (Test-Path ("$nsisdest\makensis.exe"))
}

Function Install-NSIS ($workdir) {
  $target = $tmp + $nsisInstaller
  PerformDownload "$nsisUrl" $nsisInstaller "69-C2-AE-5C-9F-2E-E4-5B-06-26-90-5F-AF-FA-A8-6D-4E-2F-C0-D3-E8-C1-18-C8-BC-68-99-DF-68-46-7B-32"
  # By piping to Write-Host, we force the script to wait
  Invoke-CommandChecked $target /S
}

Function Test-NSISAdvancedLogging () {
  $nsisdest = $programFiles32 + "\NSIS"
  $nsiscomm = $nsisdest + '\makensis.exe'
  $nsisout = & $nsiscomm "/HDRINFO"
  return (([String]$nsisout).Contains("NSIS_CONFIG_LOG"))
}

Function Install-NSISAdvancedLogging () {
  $zip_fullname = $tmp + $nsisLogInstaller
  PerformDownload "$nsisLogUrl" $nsisLogInstaller "B1-BA-3B-81-E2-1F-88-F9-7D-A0-D0-76-91-6B-FF-25-88-44-07-70-0B-04-51-9C-7B-D1-5E-6D-49-6F-F4-25"
  # Pile of pain to unzip using built in unzipper
  # Pass it the zip file and destination before running copyhere
  # 0x14 is a combination of:
  #     0x10 - overwrite existing files
  #     0x4  - hide windows dialog box
  # Should be better than hoping the "unzip" program in cygwin is working from the command line at this stage
  $shell_app = New-Object -com Shell.Application
  $zip_file = $shell_app.namespace($zip_fullname)
  $zip_dest = $shell_app.namespace($nsisdest)
  $zip_dest.Copyhere($zip_file.items(), 0x14)
}

function Test-GnuPG {
  return (Test-Path ($programFiles32 + "\GNU\GnuPG\pub\gpg.exe"))
}

function Install-GnuPG {
  cd $env:temp
  $gnupgsetup = $tmp + $gpgInstaller
  PerformDownload "$gpgUrl" $gpgInstaller "57-03-06-34-D0-DF-C5-00-BD-D1-15-00-38-70-E6-9F-87-CA-28-EC-E7-D7-C3-B1-A8-F3-BC-96-6C-BC-E5-C0"
  Invoke-CommandChecked $gnupgsetup /S
  # The previous adds an entry to the path, which doesn't get auto updated.
  # Updating the path to be able to use gpg later in the script
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

function Test-Cygwin {
  return (Test-Path ("C:\cygwin\bin"))
}

function Install-Cygwin {
  cd $env:temp
  $cygwinsetup = $tmp + $cygwinInstaller
  PerformDownloadGpg "$cygwinUrl" $cygwinInstaller "https://cygwin.com/key/pubring.asc" "https://cygwin.com/setup-x86.exe.sig"
  
  # Ideally we would like to run the cygwin installer with something like the following package list:
  #  -P "vim,git,rsync,zip,unzip,libiconv,guilt,openssh"
  # Optionally, use the system's HTTP proxy settings, if set.
  # Unfortunately doing this with the -q silent option does not work. The workaround is to do the following:
  # 1. Add the -X option to the command line below, disabling validation of setup.ini
  # 2. From the local package repository mirror, get a copy of setup.bz2 and unpack it.
  # 3. Open the "setup" file that is unzipped and change the Category of each of the package list items you want to be "Base".
  # 4. Make a copy of setup as setup.ini and bzip2 the new setup back to setup.bz2.
  # 5. Overwrite setup.ini and setup.bz2 in the root of the mirror with these new files.

  # NOTE:  Looks like the issue above might have been due to picking a mirror and resolved by
  #        -O and -s below.  Need to make sure git, zip, and unzip are the only packages needed.
  $ProxyEnable = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyEnable
  if ($ProxyEnable -eq "1")
  {
    $ProxyHost = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyServer
    Invoke-CommandChecked $cygwinsetup -q -p $ProxyHost -X -O -s http://www.mirrorservice.org/sites/sourceware.org/pub/cygwin/ -P "git,zip,unzip,mkisofs" | Write-Host
  }
  else
  {
    Invoke-CommandChecked $cygwinsetup -q -X -O -s http://www.mirrorservice.org/sites/sourceware.org/pub/cygwin/ -P "git,zip,unzip,mkisofs" | Write-Host
  }
}

function Test-7zip {
  return Test-Path($programFiles32 + "\7-Zip\7z.exe")
}

function Install-7zip {
  $szsetup = $tmp + $szInstaller
  PerformDownload "$szUrl" $szInstaller "FE-48-07-B4-69-8E-C8-9F-82-DE-7D-85-D3-2D-EA-A4-C7-72-FC-87-15-37-E3-1F-B0-FC-CF-44-73-45-5C-B8"
  Invoke-CommandChecked msiexec /i $szsetup /q
}

function Test-DotNet45 {
  if (-Not (Test-Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full')) {
    return $false
  }
  $instVerObject = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name "Version" -ErrorAction SilentlyContinue
  $instVer = [version]$instVerObject.Version
  return ($instVer -ge [version]"4.5")
}

function Install-DotNet45 {
  $dnsetup = $tmp + $dotnetInstaller
  PerformDownload "$dotnetUrl" $dotnetInstaller "6C-2C-58-91-32-E8-30-A1-85-C5-F4-0F-82-04-2B-EE-30-22-E7-21-A2-16-68-0B-D9-B3-99-5B-A8-6F-37-81"
  Invoke-CommandChecked $dnsetup /passive /norestart
}

function Test-WinDDK710 {
  if ($arch -eq "AMD64") {
    $regPath = "HKLM:\Software\Wow6432Node\Microsoft\KitSetup\configured-kits\{B4285279-1846-49B4-B8FD-B9EAF0FF17DA}\{68656B6B-555E-5459-5E5D-6363635E5F61}"
  } else {
    $regPath = "HKLM:\Software\Microsoft\KitSetup\configured-kits\{B4285279-1846-49B4-B8FD-B9EAF0FF17DA}\{68656B6B-555E-5459-5E5D-6363635E5F61}"
  }
  $version = (Get-ItemProperty $regPath -Name "kit-version-major" -ErrorAction SilentlyContinue)."kit-version-major"
  return ($version -eq 7)
}

function Install-WinDDK710 {
  $wdiso = $tmp + $winddkInstaller
  PerformDownload "$winddkUrl" $winddkInstaller "5E-DC-72-3B-50-EA-28-A0-70-CA-D3-61-DD-09-27-DF-40-2B-7A-86-1A-03-6B-BC-F1-1D-27-EB-BA-77-65-7D"
  $folderunpacked = $env:temp + "\winddk-unpacked"
  $setup = $folderunpacked + "\KitSetup.exe"
  & ($programFiles32 +'\7-Zip\7z.exe') "x" "-y" "-o$folderunpacked" $wdiso
  Invoke-CommandChecked $setup /install ALL /ui-level EXPRESS
}

function Test-WDK8 {
  if ($arch -eq "AMD64") {
    $regPath = "HKLM:\Software\Wow6432Node\Microsoft\Windows Kits\WDK"
  } else {
    $regPath = "HKLM:\Software\Microsoft\Windows Kits\WDK"
  }
  $version = [version](Get-ItemProperty $regPath -name "WDKProductVersion" -ErrorAction SilentlyContinue).WDKProductVersion
  return ($version -ge [version]"8.59.29757")
}

function Install-WDK8 {
  $exe = $tmp + $wdkInstaller
  $msi = $tmp + $wdkCoInstaller
  PerformDownload "$wdkUrl" $wdkInstaller "83-35-88-1E-40-20-DE-B6-ED-4C-E3-5C-CC-8E-EC-A0-E6-83-66-E6-B7-4C-E1-8F-A1-42-E2-92-0E-DD-34-CE"
  Invoke-CommandChecked $exe /q /norestart
  # ideally I'd like find out how to detect whether the coinstaller is installed separately to the wdksetup, and handle the
  # coinstaller as a separate package.
  PerformDownload "$wdkCoUrl" $wdkCoInstaller "29-31-42-07-81-4C-E9-D5-D7-36-95-F7-E9-23-95-39-CF-37-C7-9E-75-0B-9D-5E-A5-A5-EF-54-87-A5-83-D6"
  Invoke-CommandChecked msiexec.exe /i $msi /qn
}

function Test-PathAdditions {
  $curpath = [Environment]::GetEnvironmentVariable("Path")
  foreach ($elem in $pathelements) {
    if (-Not ($curpath.Contains($elem))) {
       return $false
    }
  }
  return $true
}

function Install-PathAdditions {
  $curpath = [Environment]::GetEnvironmentVariable("Path")
  foreach ($elem in $pathelements) {
    if (-Not ($curpath.Contains($elem))) {
      $curpath = $curpath + ";$elem"
      Write-Host "adding [$elem] to path"
    }
  }
  [Environment]::SetEnvironmentVariable("Path", $curpath, [System.EnvironmentVariableTarget]::Machine)
  Write-Host "path now $curpath"
}

function IsSqlSceInRegistry {
  return (Get-ItemProperty "HKLM:\Software\Microsoft\Microsoft SQL Server Compact Edition\v4.0" -Name "Version" -ErrorAction SilentlyContinue)
}

# VisualStudio will reboot during install (even if we tell it not to)
# if SQL Server Compact Edition is not installed. So we install the 32 bit versiona
# (and the 64 bit version on AMD64)
function Test-SqlSce32 {
  if ($arch -ne "x86") {
    return $true
  }
  return (IsSqlSceInRegistry)
}

function Install-SqlSce32 {
  $ssce32 = $tmp + $sqlsce32Installer
  PerformDownload "$sqlsce32Url" $sqlsce32Installer "EB-46-3C-0F-ED-ED-F1-77-C9-C2-8A-59-26-D9-8B-1B-AC-95-76-12-67-9E-3D-4F-0E-9A-D5-AD-A1-08-24-E7"
  Invoke-CommandChecked $ssce32 /package /passive
  Write-Host "Please reboot your machine now then rerun this script. Otherwise the Visual Studio 2012 install will probably fail."
  Exit 4
}

function Test-SqlSce64 {
  if ($arch -ne "AMD64") {
    return $true
  }
  return (IsSqlSceInRegistry)
}

function Install-SqlSce64 {
  $ssce64 = $tmp + $sqlsce64Installer
  PerformDownload "$sqlsce64Url" $sqlsce64Installer "29-E5-FF-4B-47-8C-D6-70-9A-C2-A0-D4-A5-E0-65-CC-EC-14-E5-B7-B9-72-B6-AF-C8-52-B4-98-C0-3C-40-D0"
  Invoke-CommandChecked $ssce64 /package /passive
  Write-Host "Please reboot your machine now then rerun this script. Otherwise the Visual Studio 2012 install will probably fail."
  Exit 5
}

function Test-VS2012 {
  if ($arch -eq "AMD64") {
    $regPath = "HKLM:\Software\Wow6432Node\Microsoft\DevDiv\vc\Servicing\11.0\CompilerCore"
  } else {
    $regPath = "HKLM:\Software\Microsoft\DevDiv\vc\Servicing\11.0\CompilerCore"
  }
  return (Get-ItemProperty $regPath -Name "Version" -ErrorAction SilentlyContinue)
}

function Install-VS2012 {
  $vs = $tmp + $vs2012Installer
  $log = $env:temp+'\vs_premium.log'
  PerformDownload "$vs2012Url" $vs2012Installer "B5-15-FA-B8-FE-17-F5-EA-F9-1F-5C-64-57-44-6F-96-38-EF-C2-CA-FD-9B-CC-BD-3A-19-01-DC-BB-7A-3B-F6"
  Invoke-CommandChecked $vs /passive /norestart /Log $log
}

# TODO: update to 8.1 SDK. I understand the 8.0 SDK is no longer supported.
# The 8.1 SDK is at http://download.microsoft.com/download/B/0/C/B0C80BA3-8AD6-4958-810B-6882485230B5/standalonesdk/sdksetup.exe
function Test-Win8SDK {
  if ($arch -eq "AMD64") {
    $regPath = "HKLM:\Software\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v8.0a"
  } else {
    $regPath = "HKLM:\Software\Microsoft\Microsoft SDKs\Windows\v8.0a"
  }
  $sdkVersionObject = Get-ItemProperty $regPath -Name "ProductVersion" -ErrorAction SilentlyContinue
  $sdkVersion = [version]$sdkVersionObject.ProductVersion
  return ($sdkVersion -ge [version]"8.0.50709")
}

function Install-Win8SDK {
  $sdk = $tmp + $win8sdkInstaller
  $log = $env:temp+'\win8sdk.log'
  PerformDownload "$win8sdkUrl" $win8sdkInstaller
  Invoke-CommandChecked $sdk /q /norestart /Log $log
}

# TODO: does this work on AMD64?
function Test-Wix {
  return Test-Path($programFiles32+'\WiX Toolset v3.11\bin\wix.dll')
}

function Install-Wix {
  $wixsetup = "$tmp" + "$wixInstaller"
  PerformDownload "$wixUrl" "$wixInstaller" "32-BB-76-C4-78-FC-B3-56-67-1D-4A-AF-00-6A-D8-1C-A9-3E-EA-32-C2-2A-94-01-B1-68-FC-74-71-FE-CC-D2"
  Invoke-CommandChecked "$wixsetup" -passive
}

function Test-CAPICOM {
  $dll = $programFiles32+"\Microsoft CAPICOM 2.1.0.2 SDK\Lib\X86\capicom.dll"
  return (Test-Path($dll))
}

function Install-CAPICOM {
  $capicom = $tmp + $capicomInstaller
  $dll = $programFiles32+"\Microsoft CAPICOM 2.1.0.2 SDK\Lib\X86\capicom.dll"
  PerformDownload "$capicomUrl" $capicomInstaller
  Invoke-CommandChecked msiexec.exe /i $capicom /qn
  Invoke-CommandChecked regsvr32 $dll /s
}

function Test-VS2012U4 {
  if ($arch -eq "AMD64") {
    $regPath = "HKLM:\Software\Wow6432Node\Microsoft\DevDiv\vc\Servicing\11.0\CompilerCore"
  } else {
    $regPath = "HKLM:\Software\Microsoft\DevDiv\vc\Servicing\11.0\CompilerCore"
  }

  $vsVersionObject = Get-ItemProperty $regPath -Name "Version" -ErrorAction SilentlyContinue
  $vsVersion = [version]$vsVersionObject.Version
  return $vsVersion -ge [version]"11.0.61030"
}

function Install-VS2012U4 {
  $vsu = $tmp + $vs2012u4Installer
  $log = $env:temp+'\VS2012.4.log'
  PerformDownload "$vs2012u4Url" $vs2012u4Installer
  Invoke-CommandChecked $vsu /Passive /norestart /log $log
}

function Test-Python {
  $exe = "C:\Python27\python.exe"
  return (Test-Path($exe))
}

function Install-Python {
  $python = $tmp + $pythonInstaller
  $arch = ([System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE"))
  if ($arch -eq "AMD64") {
    PerformDownload "$python64Url" $pythonInstaller
  } else {
    PerformDownload "$pythonUrl" $pythonInstaller
  }
  Invoke-CommandChecked msiexec.exe /i $python /qn
}
