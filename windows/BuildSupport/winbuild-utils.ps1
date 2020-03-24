############################################################################
### Windows build utility functions                                      ###
### No arguments                                                         ###
###                                                                      ###
### To work properly with Buildbot, the following return code conventions###
### should be used:                                                      ###
### Value: 0; color: green; a successful run                             ###
### Value: 1; color: orange; a successful run, with some warnings        ###
### Value: 2; color: red; a failed run, due to problems in the build step###
### Either return these values or use the globals                        ###
############################################################################

$global:builddir
$global:logddir
$global:cfgfile
$global:logfile

function IsNumeric([string]$s)
{
    Trap [Exception] {
        return $false
    }
    $tmp = 0
    $isnum = [System.Int32]::TryParse($s, [ref]$tmp)
    return $isnum
}

function ExitWithCode([int32]$exitcode)
{
    $host.SetShouldExit($exitcode)
    Exit
}

function read-config-value([string]$config, [string]$name)
{
    [System.Xml.XmlDocument] $xd = New-Object System.Xml.XmlDocument

    $xd.Load($config)
    
    $node = $xd.SelectSingleNode("/WinbuildConfig/{0}" -f $name)

    if (!$node)
    {
        return
    }
    return $node.get_InnerXml()
}

function write-config-value([string]$config, [string]$name, [string]$value)
{
    [System.Xml.XmlDocument] $xd = New-Object System.Xml.XmlDocument

    $xd.Load($config)
    
    $node = $xd.SelectSingleNode("/WinbuildConfig/{0}" -f $name)

    if (!$node)
    {
        return $false
    }
    $node.set_InnerXml($value)
    
    $xd.Save($config)
    return $true
}

function enable-read-execute([string]$file)
{
    $acl = Get-Acl $file
    $ar = New-Object System.Security.Accesscontrol.FileSystemAccessRule("Everyone", "ReadAndExecute", "Allow")
    $acl.SetAccessRule($ar)
    Set-Acl $file $acl
}

function get-version-string()
{
    return ((read-config-value -config $global:cfgfile -name "VerMajor") + "." +
            (read-config-value -config $global:cfgfile -name "VerMinor") + "." +
            (read-config-value -config $global:cfgfile -name "VerMicro") + "." +
            (read-config-value -config $global:cfgfile -name "BuildNumber"))
}

function parse-version-string([string]$strver)
{
    $regex = [regex]"^(?:(\d+)\.)?(?:(\d+)\.)?(?:(\d+)\.)?(\*|\d+)"
    $result = $regex.Matches($strver)
    return @($result[0].Groups[1].Value,
             $result[0].Groups[2].Value,
             $result[0].Groups[3].Value,
             $result[0].Groups[4].Value)
}

# Now we use Start-Transcript for logging we don't need this but keep it 
# for now until all the calls have been replaced with Write-Host commands
function log-info([string]$info)
{
    Write-Host $info
}

function log-script-end()
{
    log-info -info "--------------------------------------------------------"
    log-info -info  ("                     Script End")
	log-info -info "--------------------------------------------------------"
}

function log-info-wrap([string]$info)
{
	log-info -info "--------------------------------------------------------"
	log-info -info $info
	log-info -info "--------------------------------------------------------"
}

# Now we use Start-Transcript for logging we don't need this but keep it 
# for now until all the calls have been replaced with Write-Host commands
function log-error([string]$err)
{
    Write-Host $err
}

function execute-log-and-out([string]$command)
{
       $out = Invoke-Expression $command #Do the command
       #Write-Host $out #To stdout
       $out | Foreach-Object {$_.ToString()} | Write-Host
               
}

function common-init([string]$cmdinv)
{    
    # The PWD is always assumed to be the build dir
    $global:builddir = [System.IO.Directory]::GetCurrentDirectory()

    # Make sure the config file is present. Running winbuild-prepare.ps1 would have copied
    # the config file to the build dir and updated it.
    $global:cfgfile = ($global:builddir + "\config.xml")
    if (!(Test-Path -Path $global:cfgfile -PathType Leaf))
    {
        Write-Host "ERROR: Config file not present - config:" $global:cfgfile
        return $false
    }

    # Setup the log file, create the logging dir if not present
    # Note the syntax when calling functions. If you supply a comma separated list (w/ or w/o
    # parens), ps turns it into an array assigned to the first arg.
    $global:logdir = read-config-value -config $global:cfgfile -name "LogDir"
    if ($global:logdir.Length -lt 1)
    {
        Write-Host "ERROR: No LogDir in the config file"
        return $false
    }
    $global:logdir = $global:builddir + "\" + $global:logdir
    if (!(Test-Path -Path $global:logdir -PathType Container))
    {
        New-Item -Path $global:logdir -Type Directory -Force
    }
    $ts = get-date -uformat "%Y-%m-%d-%H%M%S"
    $global:logfile = $global:logdir + "\" + $cmdinv + "_"+ $ts +".log"
    Write-Host "Logging to [$global:logfile]"
    Start-Transcript $global:logfile
    Write-Host "Logging started to [$global:logfile]"
    # Trace out a basic log header
    log-info -info "--------------------------------------------------------"
    log-info -info ("Windows Build Log - " + (Get-Date))
    log-info -info ("Command:     " + $cmdinv)
    log-info -info ("Working Dir: " + $global:builddir)
    log-info -info ("Logging To:  " + $global:logfile)
    log-info -info "--------------------------------------------------------"

    return $true
}

# Get the "Software" key path for a 32bit app, on a 64bit OS this will include "Wow6432Node".
# 
function get-software-key-path32([string]$key)
{
    $path = "Registry::HKEY_LOCAL_MACHINE\Software"
    
    $arch = ([System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE"))
    if ($arch -eq "AMD64")
    {
        $path += "\Wow6432Node"
    }

    if ($key.Length -gt 0)
    {    
        $path += "\" + $key
    }
    return $path
}

# Get the "Program Files" path for a 32bit app, on a 64bit OS this will be "C:\Program Files (x86)"
#
function get-program-files-path32([string]$file)
{
    $programFiles = "ProgramFiles"
    
    $arch = ([System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE"))
    if ($arch -eq "AMD64")
    {
        $programFiles += "(x86)"
    }

    $path = ([System.Environment]::GetEnvironmentVariable($programFiles))

    if ($file.Length -gt 0)
    {  
        $path += "\" + $file
    }
    return $path
}
