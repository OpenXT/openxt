############################################################################
### Script to prepare for a build                                        ###
### Sanity checks input, host configuration and config                   ###
### Prepares build directory                                             ###
### Arguments (See usage function, pretty self explanatory)              ###
############################################################################

#Calling a script does not change the working directory, instead use the invocation path to ensure we're in the right place
$mywd = (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $mywd

# Import useful functions into prepare
. ".\BuildSupport\winbuild-utils.ps1"

# Top level usage help for winbuild-prepare.ps1 and winbuild-all.ps1
function usage([string]$cmdinv)
{
    Write-Host $cmdinv ": Must supply config, tag and build args"
    Write-Host "Usage:"
    Write-Host "  config=<config-file>"
    Write-Host "  branch=<build-branch> [optional, default is master]"
    Write-Host "  build=<build-number> [optional]"
    Write-Host "  tag=<build-tag> [optional, default is no tag]" 
    Write-Host "  type=Release|Debug [optional, default is Release]"
    Write-Host "  developer=true|false [optional, default is false (i.e. release build)]"
    Write-Host "  certname=<signing-certificate-name> [optional]"
    Write-Host "  license=<license-text-file> [optional]"
}

function update-version-value($name, $value)
{
    if ($value.Length -gt 0)
    {
        $intval = ($value -as [System.Int32])
        if (($intval -lt 0) -or ($intval -gt 65535))
        {
            throw "Invalid version value! - name: $name value: $value"
        }

        $ret = write-config-value -config $global:cfgfile -name $name -value $value
        if (!$ret)
        {
            throw "Failed to update config file with version! - name: $name value: $value"
        }
    }
    else
    {
        throw "Failed to update config file with version! - name: $name value: $value"
    }
}

# Validate the given input and update the config file
function update-config-file($argtable)
{
    #The version file must be present in the parent directory...
    $contents = Get-Content ..\version | %{$versionValues = @{}} {if ($_ -match "(.*)=(.*)") {$versionValues[$matches[1]]=$matches[2];}}

    if(!$?){
        throw "Could not read version file"
    }

    Write-Output "Version File Contents:"
    $versionValues | Out-String | Write-Output

    # This argument has to be here as it is mandatory
    if ($argtable["build"].Length -lt 1)
    {
        throw "No build number value specified in the input!"
    }

    # The Windows tools build number is truncated from the XenClient
    # build number using the following arguments. Note if the Windows
    # build number is explicitly used, it will pass through the following
    # unchanged.
    $intval = ($argtable["build"] -as [System.Int32])
    if ($intval -gt 110000)
    {
        $intval -= 110000
    }

    $intval %= 65536
    $argtable["build"] = $intval.ToString()

    update-version-value -name "VerMajor" -value $versionValues["XC_TOOLS_MAJOR"].replace('"', '')
    update-version-value -name "VerMinor" -value $versionValues["XC_TOOLS_MINOR"].replace('"', '')
    update-version-value -name "VerMicro" -value $versionValues["XC_TOOLS_MICRO"].replace('"', '')
    update-version-value -name "BuildNumber" -value $argtable["build"]

    if ($argtable["branch"].Length -gt 0)
    {
        $ret = write-config-value -config $global:cfgfile -name "BuildBranch" -value $argtable["branch"]
        if (!$ret)
        {
            throw "Failed to update config file with branch value!"
        }
    }
    else
    {
        if ($argtable["tag"].Length -eq 0)
        {
            $ret = write-config-value -config $global:cfgfile -name "BuildBranch" -value "master"
            if (!$ret)
            {
                throw "Failed to update config file with branch value!"
            }
        } else {
            Write-Output "as you did not provide any branch we will use the tag value"
        }
    }

    if (($argtable["tag"].Length -gt 0) -and ($argtable["branch"].Length -eq 0))
    {
        $ret = write-config-value -config $global:cfgfile -name "BuildTag" -value $argtable["tag"]
        if (!$ret)
        {
            throw "Failed to update config file with tag value!"
        }
    }
    else
    {
        Write-Output "Config not using build tag in build."
    }

    $ret = write-config-value -config $global:cfgfile -name "VerString" -value (get-version-string)
    if (!$ret)
    {
        throw "Failed to update config file with version string value!"
    }

    if ($argtable["type"].Length -gt 0)
    {
        $typeval = ""
        if ($argtable["type"].ToLower().CompareTo("release") -eq 0)
        {
            $typeval = "Release"
        }
        if ($argtable["type"].ToLower().CompareTo("debug") -eq 0)
        {
            $typeval = "Debug"
        }
        if ($typeval.Length -eq 0)
        {
            throw ("Invalid build signing value! - value: " + $argtable["type"])
        }

        $ret = write-config-value -config $global:cfgfile -name "BuildType" -value $typeval
        if (!$ret)
        {
            throw "Failed to update config file with build type! - value: $typeval"
        }
    }

    if ($argtable["developer"].Length -gt 0)
    {
        $devmode = ""
        if ($argtable["developer"].ToLower().CompareTo("false") -eq 0)
        {
            $devmode = "false"
        }
        if ($argtable["developer"].ToLower().CompareTo("true") -eq 0)
        {
            $devmode = "true"
        }
        if ($devmode.Length -eq 0)
        {
            throw ("Invalid build developer mode value! - value: " + $argtable["developer"])
        }

        $ret = write-config-value -config $global:cfgfile -name "Developer" -value $devmode
        if (!$ret)
        {
            throw "Failed to update config file with developer flag! - value: $devmode"
        }
    }

    if ($argtable["certname"].Length -gt 0)
    {
        $ret = write-config-value -config $global:cfgfile -name "CertName" -value $argtable["certname"]
        if (!$ret)
        {
            throw ("Failed to update config file with signing certificate name! - value: " + $argtable["certname"])
        }
    }

    if ($argtable["license"].Length -gt 0)
    {
        if (!(Test-Path -Path $argtable["license"] -PathType Leaf))
        {
            throw ("Failed to locate license file! - value: " + $argtable["license"])
        }

        $ret = write-config-value -config $global:cfgfile -name "License" -value $argtable["license"]
        if (!$ret)
        {
            throw ("Failed to update config file with license file! - value: " + $argtable["license"])
        }
    }

    # Update "Program Files" to "Program Files (x86)" for VS running on x64 machine.
    #
    $arch = ([System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE"))
    if ($arch -eq "AMD64")
    {
        $vsdir = read-config-value -config $global:cfgfile -name "VSDir"
        $vsdir = $vsdir.Replace("\Program Files\", "\Program Files (x86)\")
        $ret = write-config-value -config $global:cfgfile -name "VSDir" -value $vsdir
        if (!$ret)
        {
            throw "Failed to update config file with VS path (32bit) - value: $vsdir"
        }
    }
}

# Returns true if command found, false otherwise
# Silences any errors that running the command generates
# NEVER USE THIS TO SERIOUSLY EXECUTE COMMANDS - YOU DO SO AT YOUR OWN RISK
function try-command([string]$command)
{
    & {
        trap [Management.Automation.CommandNotFoundException]
        {
            throw "Command $command was unsuccessful"
        }
        & $command 2>&1> $null
    }
}

#Check for all the necessary build bits
function check-platform()
{
    Write-Output "--------------------------------------------------------"
    Write-Output "Checking platform configuration..."
    Write-Output "--------------------------------------------------------"
    Write-Output "Machine search path: "
    $path = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    Write-Output $path
    Write-Output "`nChecking for access to necessary executables..."
    
    # Cygwin is a 32bit application 
    $cygkey = get-software-key-path32 -key Cygwin\setup
    $cygdir = (Get-ItemProperty $cygkey rootdir).rootdir
    if ($cygdir.Length -lt 0)
    {
        throw "Check for CYGWIN failed, not installed"
    }
    $cygver = & uname -r
    Write-Output ("Found CYGWIN version: $cygver rootdir: $cygdir ...")


    try-command -command "unzip"
    Write-Output "Found UNZIP command ..."
    
    # NSIS is a 32bit application
    $nsiskey = get-software-key-path32 -key NSIS
    $tmparr = @(0..1)
    $tmparr[0] = (Get-ItemProperty $nsiskey VersionMajor).VersionMajor
    $tmparr[1] = (Get-ItemProperty $nsiskey VersionMinor).VersionMinor
    # NSIS Check we are running grater than 2.23
    if (($tmparr[0] -ne 2) -or ($tmparr[1] -lt 23))
    {
        throw ("NSIS invalid version - major: " + $tmparr[0] + " minor: " + $tmparr[1])
    }
    Write-Output ("Found NSIS version " + $tmparr[0] + "." + $tmparr[1]  + " ...")

    try-command -command "makensis"
    Write-Output "Found NSIS command ..."        

    # Basic check to see if the specified WDK is there. If this check needs to enhanced,
    # additionally it can scan the kits under:
    # HKLM\Software\Microsoft\KitSetup\{B4285279-1846-49B4-B8FD-B9EAF0FF17DA}
    # Under each kit there is a setup-install-location value that can be matched to
    # DdkDir and then the version can be validated.
    $ddkdir = read-config-value -config $global:cfgfile -name "DdkDir"
    if ($ddkdir.Length -lt 1)
    {
        throw "DdkDir value missing from configuration file"
    }
    $setenv = $ddkdir + "\bin\setenv.bat"
    try-command -command $setenv
    $relsrc = $ddkdir + "\relnote.htm"
    $reldst = $global:logdir + "\ddk-release-notes.htm"
    Copy-Item -Path $relsrc -Destination $reldst
    Write-Output "Found WINDDK release notes: $reldst ..."

    #Certificate verification bits
    $signtool = $ddkdir + "\bin\x86\signtool.exe"
    try-command -command $signtool
    Write-Output "Found SIGNTOOL command ..."

    $certname = read-config-value -config $global:cfgfile -name "CertName"
    if ($certname.Length -lt 1)
    {
        throw "CertName value missing from configuration file"
    }

    #Test the certificate exists
    $certresult = Get-ChildItem -Path cert:\CurrentUser\My | Select-Object -Property Subject | Select-String "CN=$certname"
    if ($certresult -eq $null)
    {
        throw "Given certificate `"$certname`" is not available on your system, failing build"
    }

    #Test the certificate is not due to expire
    $certresult = Get-ChildItem -Path cert:\CurrentUser\My | where { $_.notafter -le (get-date).AddDays(3) } | Select-Object -Property Subject | Select-String "CN=$certname"
    if ($certresult -ne $null)
    {
        throw "Certificate `"$certname`" is due to expire VERY soon, failing build"
    }

    try-command -command ("inf2cat.exe")
    Write-Output "Found INF2CAT command ..."

    # For Visual Studio, just find the value that specifies the location of
    # devenv.exe and try to run it. If this needs to be extended, checks
    # for C++ and C# can be added.
    # Te key is stored under the 32 bit path
    $vssetup = get-software-key-path32 -key Microsoft\VisualStudio\11.0\Setup\VS 
    $devenv = (Get-ItemProperty $vssetup EnvironmentPath).EnvironmentPath
    if ($devenv.Length -lt 1)
    {
        throw "Could not find Visual Studio 11.0 EnvironmentPath registry value"
    }
    Write-Output "Found VS 11.0 ..."
    if (!(Test-Path -Path $devenv -PathType Leaf))
    {
        throw ("Check for DEVENV failed, not installed")
    }
    Write-Output "Found DEVENV command ..."

    $vsver = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($devenv).FileVersion
    $vsvers = parse-version-string -strver $vsver
    # Check the version numbers to see if this is VS 9.0 with SP1 or greater. The target value is
    # 9.0.30729.1 but we already know it is VS 9. If the minor is greater than 0 it must be something newer.
    if ($vsvers[1] -eq 0)
    {
        if ($vsvers[2] -ge 50522)
        {
            Write-Output "Found VS 11.0 RC or newer version: $vsver ..."
        }
        else
        {
            throw "VS 11.00 version older than RC: $vsver ..."
        }
    }
    else
    {
        Write-Output "Found VS 11.0 newer version: $vsver ..."
    }

    $msbuild = read-config-value -config $global:cfgfile -name "MSBuild"
    if ($msbuild.Length -lt 1)
    {
        throw "MsBuild value missing from configuration file"
    }
    try-command -command $msbuild
    Write-Output "Found MSBUILD command ..."

    #Check for Win8 SDK
    $sdkKey = get-software-key-path32 -key "Microsoft\Microsoft SDKs\Windows\v8.0"
    $sdkDir = (Get-ItemProperty -Path $sdkKey).InstallationFolder
    if ($sdkDir.Length -lt 0)
    {
        throw "Check for Windows 8 SDK failed, not properly installed"
    }
    Write-Output "Found Win8 SDK at: $sdkDir"

    #Check for Win8 WDK
    $wdkKey = get-software-key-path32 -key "Microsoft\Windows Kits\WDK"
    $wdkDir = (Get-ItemProperty -Path $wdkKey).WDKContentRoot
    if ($wdkDir.Length -lt 0)
    {
        throw "Check for Windows 8 WDK failed, not properly installed"
    }
    Write-Output "Found Win8 WDK at: $wdkDir"
    
    # Test for WIX executables
    #
    $light = $env:WIX + "bin\light.exe"
    try-command -command $light
    $candle = $env:WIX + "bin\candle.exe"
    try-command -command $candle
    Write-Output "Found WIX commands ..."
}

#All the bits that must come before the main as they can not be logged yet...
function pre-main($argtable)
{
    $config = $argtable["config"]
    if ($config.Length -lt 1)
    {
        throw "No config file value specified"
        ExitWithCode -exitcode $global:failure
    }

    #Copy the selected config to build root
    Copy-Item -Path ".\config\$config" -Destination ".\config.xml"
    $config = ".\config.xml"

    #Check that there was a config and that it copied ok
    if (!(Test-Path -Path $config -PathType Leaf))
    {
        throw "Config file not found - config: $config"
    }
    
    # Set full path to config file
    $global:cfgfile = "$mywd\config.xml"
    
    # Setup the log file, create the logging dir if not pre-defined
    $global:logdir = read-config-value -config $global:cfgfile -name "LogDir"
    if ($global:logdir.Length -lt 1)
    {
        # No value specified, roll with the default
        if (!(write-config-value -config $global:cfgfile -name "LogDir" -value "logs"))
        {
            throw "Failed to update config file with logs directory"
        }
        
        $global:logdir = "$mywd\logs"
    }
    
    # Create the logs directory if it does not exist
    if (!(Test-Path -Path $global:logdir -PathType Container))
    {
        New-Item -Path $global:logdir -Type Directory -Force
    }
    
    # Check creation went OK
    if (!(Test-Path -Path $global:logdir -PathType Container))
    {
        throw "Failed to create logs directory"
    }
    $global:logfile = "$global:logdir\winbuild-prepare.log"
}

#Main build function
function winbuild-main([string]$cmdinv, $argtable)
{
    Write-Output "--------------------------------------------------------"
    Write-Output ("Windows Build Log - " + (Get-Date))
    Write-Output "Command:     $cmdinv"
    Write-Output "Working Dir: $global:builddir"
    Write-Output "Logging To:  $global:logfile"
    Write-Output "--------------------------------------------------------"
    
    #Output arguments to log and stdout
    Write-Output "Script running on $Env:Computername"
    Write-Output "`nArg Table:"
    $argtable | Out-String | Write-Output
    
    # Update the config file with the input values. After this point, we will rely solely
    # on the config file for settings.
    update-config-file -argtable $argtable
    
    Write-Output "Config file updated with input parameter values"
    
    # Do a platform sanity check
    check-platform

}

#########################################################
##### Begin script, do some basic checks, call main #####
#########################################################
if (($args.Length -eq 1) -and ($args[0].ToLower().CompareTo("--help") -eq 0))
{
    usage -cmdinv $MyInvocation.MyCommand.Name
    ExitWithCode -exitcode $global:failure
}

if (($args.Length -lt 2) -or ($args.Length -gt 12))
{
    usage -cmdinv $MyInvocation.MyCommand.Name
    ExitWithCode -exitcode $global:failure
}

# Split each key-value pair into hash table entries and call main
$args | Foreach-Object {$argtable = @{}} {if ($_ -Match "(.*)=(.*)") {$argtable[$matches[1]] = $matches[2];}}
pre-main -argtable $argtable
winbuild-main -cmdinv $MyInvocation.MyCommand.Name -argtable $argtable | Foreach-Object {$_.ToString()} | Tee-Object $global:logfile
